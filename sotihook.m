/*
 * 小包搜题 Hook - 拦截搜索，先题库后大模型
 * 
 * Hook点: 主App的搜索方法
 * 策略: 先走原App题库搜索，结果为空时调用DeepSeek API
 *
 * 编译: zig cc -target aarch64-ios -dynamiclib -o sotihook.dylib sotihook.m \
 *       -framework Foundation -framework UIKit -fobjc-arc
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <objc/runtime.h>
#include <objc/message.h>

// ============================================================================
// DeepSeek API配置
// ============================================================================
#define DEEPSEEK_API_URL "https://api.deepseek.com/chat/completions"
#define DEEPSEEK_API_KEY "YOUR_API_KEY_HERE"
#define DEEPSEEK_MODEL "deepseek-chat"

// ============================================================================
// 全局状态
// ============================================================================
static id (*original_searchTimuWithLCS)(id self, SEL _cmd, id question, id topN, id callback);
static id (*original_searchNetTikus)(id self, SEL _cmd, id query, id callback);
static id (*original_searchTimuWithIndex2)(id self, SEL _cmd, id index, id topN, id callback);

static volatile BOOL g_searching = NO;
static NSString *g_lastQuestion = nil;

// ============================================================================
// JSON工具
// ============================================================================
static NSString* json_escape_string(NSString *str) {
    if (!str) return @"";
    str = [str stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    str = [str stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    str = [str stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
    str = [str stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
    return str;
}

static NSString* extract_content_from_json(NSString *json_str) {
    // 简单解析 "content":"..."
    NSRange r1 = [json_str rangeOfString:@"\"content\":\""];
    if (r1.location == NSNotFound) {
        r1 = [json_str rangeOfString:@"\"content\": \""];
        if (r1.location == NSNotFound) return nil;
        r1.location += 12;
    } else {
        r1.location += 11;
    }
    
    NSUInteger start = r1.location;
    NSMutableString *result = [NSMutableString string];
    NSUInteger i = start;
    BOOL escaped = NO;
    
    while (i < [json_str length]) {
        unichar c = [json_str characterAtIndex:i];
        if (escaped) {
            switch (c) {
                case 'n': [result appendString:@"\n"]; break;
                case 'r': [result appendString:@"\r"]; break;
                case 't': [result appendString:@"\t"]; break;
                case '"': [result appendString:@"\""]; break;
                case '\\': [result appendString:@"\\"]; break;
                default: [result appendFormat:@"\\%C", c]; break;
            }
            escaped = NO;
        } else if (c == '\\') {
            escaped = YES;
        } else if (c == '"') {
            break;
        } else {
            [result appendFormat:@"%C", c];
        }
        i++;
    }
    return result;
}

// ============================================================================
// DeepSeek API调用 (同步，使用NSURLSession semaphore)
// ============================================================================
static NSString* call_deepseek_sync(NSString *question) {
    // 构建JSON
    NSString *escaped_q = json_escape_string(question);
    NSString *json_body = [NSString stringWithFormat:
        @"{"
        "\"model\":\"" DEEPSEEK_MODEL "\","
        "\"messages\":["
        "{\"role\":\"system\",\"content\":\"你是一个答题助手。请直接给出题目的答案，简洁明了，不要解释。如果是选择题，只给选项字母和对应内容。如果是填空题，直接给填空内容。\"},"
        "{\"role\":\"user\",\"content\":\"%@\"}"
        "],"
        "\"max_tokens\":512,"
        "\"temperature\":0.1"
        "}",
        escaped_q];
    
    // 创建请求
    NSURL *url = [NSURL URLWithString:@DEEPSEEK_API_URL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer " DEEPSEEK_API_KEY] 
        forHTTPHeaderField:@"Authorization"];
    [request setHTTPBody:[json_body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setTimeoutInterval:15];
    
    // 同步请求 (用信号量)
    __block NSString *result = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] 
        dataTaskWithRequest:request 
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSLog(@"[SotiHook] DeepSeek API错误: %@", error.localizedDescription);
            } else if (data) {
                NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"[SotiHook] DeepSeek响应: %@", json);
                result = extract_content_from_json(json);
            }
            dispatch_semaphore_signal(sem);
        }];
    [task resume];
    
    // 等待最多15秒
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC);
    dispatch_semaphore_wait(sem, timeout);
    
    return result;
}

// ============================================================================
// 拦截回调Block
// ============================================================================
typedef void (^SearchCallback)(id result);

static SearchCallback wrap_callback(SearchCallback original_cb, NSString *question) {
    if (!original_cb) return nil;
    
    // 保存原始block
    SearchCallback orig = [original_cb copy];
    
    // 返回新的block
    SearchCallback wrapped = ^void(id result) {
        BOOL hasResult = NO;
        
        if (result) {
            if ([result isKindOfClass:[NSArray class]]) {
                hasResult = [(NSArray *)result count] > 0;
            } else if ([result isKindOfClass:[NSString class]]) {
                hasResult = [(NSString *)result length] > 0;
            } else if ([result isKindOfClass:[NSDictionary class]]) {
                hasResult = [(NSDictionary *)result count] > 0;
            } else {
                hasResult = YES;
            }
        }
        
        if (hasResult) {
            // 题库有结果，直接返回
            NSLog(@"[SotiHook] 题库命中，直接返回");
            orig(result);
        } else {
            // 题库无结果，调用DeepSeek
            NSLog(@"[SotiHook] 题库未命中，调用DeepSeek...");
            
            NSString *answer = call_deepseek_sync(question);
            
            if (answer && [answer length] > 0) {
                NSLog(@"[SotiHook] DeepSeek返回答案: %@", answer);
                
                // 包装成原App格式
                NSDictionary *dict = @{
                    @"answer": answer,
                    @"q": question ?: @"",
                    @"source": @"deepseek"
                };
                orig(@[dict]);
            } else {
                NSLog(@"[SotiHook] DeepSeek无结果");
                orig(result);
            }
        }
    };
    
    return [wrapped copy];
}

// ============================================================================
// Hook函数
// ============================================================================

// Hook: searchTimuWithLCS:q:topN:callback:
static id hooked_searchTimuWithLCS(id self, SEL _cmd, id question, id topN, id callback) {
    NSString *q = nil;
    if ([question isKindOfClass:[NSString class]]) {
        q = (NSString *)question;
    }
    
    NSLog(@"[SotiHook] >>> searchTimuWithLCS: q=%@", q);
    
    // 防重复
    if (g_searching && [g_lastQuestion isEqualToString:q]) {
        NSLog(@"[SotiHook] 跳过重复搜索");
        if (callback) {
            SearchCallback cb = callback;
            cb(@[]);
        }
        return nil;
    }
    
    g_lastQuestion = [q copy];
    g_searching = YES;
    
    // 包装回调
    SearchCallback wrapped_cb = wrap_callback(callback, q);
    
    // 调用原方法
    id result = original_searchTimuWithLCS(self, _cmd, question, topN, wrapped_cb);
    
    g_searching = NO;
    return result;
}

// Hook: searchNetTikus:callback:
static id hooked_searchNetTikus(id self, SEL _cmd, id query, id callback) {
    NSString *q = nil;
    if ([query isKindOfClass:[NSString class]]) {
        q = (NSString *)query;
    }
    
    NSLog(@"[SotiHook] >>> searchNetTikus: q=%@", q);
    
    SearchCallback wrapped_cb = wrap_callback(callback, q);
    return original_searchNetTikus(self, _cmd, query, wrapped_cb);
}

// Hook: searchTimuWithIndex2:topN:callback:
static id hooked_searchTimuWithIndex2(id self, SEL _cmd, id index, id topN, id callback) {
    NSLog(@"[SotiHook] >>> searchTimuWithIndex2");
    
    // 这个方法是通过索引搜索，我们同样包装回调
    // 但不传question(因为这里用的是index)，让原逻辑处理
    return original_searchTimuWithIndex2(self, _cmd, index, topN, callback);
}

// ============================================================================
// 入口点
// ============================================================================
__attribute__((constructor))
static void soti_hook_init(void) {
    NSLog(@"");
    NSLog(@"[SotiHook] ========================================");
    NSLog(@"[SotiHook]  小包搜题 Hook v1.0 加载成功!");
    NSLog(@"[SotiHook]  策略: 先题库 → 无结果则DeepSeek");
    NSLog(@"[SotiHook] ========================================");
    NSLog(@"");
    
    // 遍历所有类，找到搜索相关的
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    
    Class targetClass = nil;
    NSMutableArray *candidates = [NSMutableArray array];
    
    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        NSString *clsName = [NSString stringWithUTF8String:name];
        
        // 找到包含search/tiku/recognize的类
        if ([clsName containsString:@"Search"] || [clsName containsString:@"Tiku"] || 
            [clsName containsString:@"Recognize"] || [clsName containsString:@"soti"] ||
            [clsName containsString:@"SOTI"] || [clsName containsString:@"Camera"]) {
            [candidates addObject:clsName];
        }
    }
    free(classes);
    
    NSLog(@"[SotiHook] 搜索相关候选类: %@", candidates);
    
    // 尝试Hook所有候选类的方法
    for (NSString *clsName in candidates) {
        Class cls = objc_getClass([clsName UTF8String]);
        if (!cls) continue;
        
        // searchTimuWithLCS:q:topN:callback:
        SEL sel1 = sel_registerName("searchTimuWithLCS:q:topN:callback:");
        Method m1 = class_getInstanceMethod(cls, sel1);
        if (m1 && !original_searchTimuWithLCS) {
            original_searchTimuWithLCS = (void *)method_getImplementation(m1);
            method_setImplementation(m1, (IMP)hooked_searchTimuWithLCS);
            NSLog(@"[SotiHook] ✓ Hook: %@ searchTimuWithLCS:q:topN:callback:", clsName);
        }
        
        // searchNetTikus:callback:
        SEL sel2 = sel_registerName("searchNetTikus:callback:");
        Method m2 = class_getInstanceMethod(cls, sel2);
        if (m2 && !original_searchNetTikus) {
            original_searchNetTikus = (void *)method_getImplementation(m2);
            method_setImplementation(m2, (IMP)hooked_searchNetTikus);
            NSLog(@"[SotiHook] ✓ Hook: %@ searchNetTikus:callback:", clsName);
        }
        
        // searchTimuWithIndex2:topN:callback:
        SEL sel3 = sel_registerName("searchTimuWithIndex2:topN:callback:");
        Method m3 = class_getInstanceMethod(cls, sel3);
        if (m3 && !original_searchTimuWithIndex2) {
            original_searchTimuWithIndex2 = (void *)method_getImplementation(m3);
            method_setImplementation(m3, (IMP)hooked_searchTimuWithIndex2);
            NSLog(@"[SotiHook] ✓ Hook: %@ searchTimuWithIndex2:topN:callback:", clsName);
        }
    }
    
    if (!original_searchTimuWithLCS && !original_searchNetTikus) {
        NSLog(@"[SotiHook] ⚠ 未找到目标方法，可能需要调整Hook点");
    }
}
