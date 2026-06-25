/*
 * 小包搜题 Frida Hook - 拦截搜索，先题库后大模型
 * 
 * 使用方式:
 * 1. TrollStore安装 FridaGadget.dylib 到小包搜题.app
 * 2. 手机上启动小包搜题
 * 3. 电脑运行: frida -U -n EasyEdgeDemo -l sotihook.js
 * 
 * 策略: 先题库搜索 → 无结果则调DeepSeek API
 */

// ============================================================================
// DeepSeek API配置
// ============================================================================
var DEEPSEEK_API_URL = "https://api.deepseek.com/chat/completions";
var DEEPSEEK_API_KEY="YOUR_API_KEY_HERE";
var DEEPSEEK_MODEL = "deepseek-chat";

// ============================================================================
// 工具函数
// ============================================================================

function log(msg) {
    console.log("[SotiHook] " + msg);
}

function callDeepSeek(question, callback) {
    var url = DEEPSEEK_API_URL;
    var body = JSON.stringify({
        model: DEEPSEEK_MODEL,
        messages: [
            {
                role: "system",
                content: "你是答题助手，直接给答案不解释。选择题只给字母，填空题直接给内容。"
            },
            {
                role: "user", 
                content: question
            }
        ],
        max_tokens: 512,
        temperature: 0.1
    });
    
    // 用ObjC的NSURLSession发请求
    var url2 = ObjC.classes.NSURL.URLWithString_(url);
    var request = ObjC.classes.NSMutableURLRequest.requestWithURL_(url2);
    request.setHTTPMethod_("POST");
    request.setValue_forHTTPHeaderField_("application/json", "Content-Type");
    request.setValue_forHTTPHeaderField_("Bearer " + DEEPSEEK_API_KEY, "Authorization");
    
    var bodyData = ObjC.classes.NSData.dataUsingEncoding_(body, 4); // NSUTF8StringEncoding
    request.setHTTPBody_(bodyData);
    
    var session = ObjC.classes.NSURLSession.sharedSession();
    
    var handler = ObjC.block(function(data, response, error) {
        if (error) {
            log("API错误: " + error.localizedDescription());
            callback(null);
            return;
        }
        
        if (data) {
            var json = ObjC.classes.NSString.alloc().initWithData_encoding_(data, 4);
            var str = json.toString();
            log("API响应: " + str.substring(0, 200) + "...");
            
            // 解析content
            var parsed = parseContent(str);
            callback(parsed);
        } else {
            callback(null);
        }
    });
    
    var task = session.dataTaskWithRequest_completionHandler_(request, handler);
    task.resume();
}

function parseContent(jsonStr) {
    // 简单JSON解析，提取content字段
    var idx = jsonStr.indexOf('"content":"');
    if (idx === -1) {
        idx = jsonStr.indexOf('"content": "');
        if (idx === -1) return null;
        idx += 12;
    } else {
        idx += 11;
    }
    
    var result = "";
    var escaped = false;
    
    for (var i = idx; i < jsonStr.length; i++) {
        var c = jsonStr[i];
        if (escaped) {
            switch (c) {
                case 'n': result += '\n'; break;
                case 'r': break;
                case 't': result += ' '; break;
                case '"': result += '"'; break;
                case '\\': result += '\\'; break;
                default: result += '\\' + c; break;
            }
            escaped = false;
        } else if (c === '\\') {
            escaped = true;
        } else if (c === '"') {
            break;
        } else {
            result += c;
        }
    }
    
    return result.length > 0 ? result : null;
}

function wrapCallback(originalCallback, question) {
    if (!originalCallback) return null;
    
    // 返回新的block
    return ObjC.block(function(result) {
        var hasResult = false;
        
        if (result) {
            var nsResult = ObjC.cast(result, ObjC.classes.NSObject);
            if (nsResult.isKindOfClass_(ObjC.classes.NSArray)) {
                hasResult = nsResult.count() > 0;
            } else if (nsResult.isKindOfClass_(ObjC.classes.NSDictionary)) {
                hasResult = nsResult.count() > 0;
            } else if (nsResult.isKindOfClass_(ObjC.classes.NSString)) {
                hasResult = nsResult.length() > 0;
            }
        }
        
        if (hasResult) {
            log("✓ 题库命中，直接返回");
            originalCallback(result);
        } else {
            log("✗ 题库未命中，调用DeepSeek: " + question);
            
            callDeepSeek(question, function(answer) {
                if (answer) {
                    log("✓ DeepSeek答案: " + answer);
                    
                    // 包装成原App格式
                    var dict = ObjC.classes.NSMutableDictionary.alloc().init();
                    dict.setObject_forKey_(answer, "answer");
                    dict.setObject_forKey_(question, "q");
                    dict.setObject_forKey_("deepseek", "source");
                    
                    var arr = ObjC.classes.NSArray.arrayWithObject_(dict);
                    originalCallback(arr);
                } else {
                    log("✗ DeepSeek无结果");
                    originalCallback(result);
                }
            });
        }
    });
}

// ============================================================================
// 主逻辑
// ============================================================================

log("========================================");
log(" 小包搜题 Hook v1.0");
log(" 策略: 先题库 → 无结果则DeepSeek");
log("========================================");

// 枚举所有类，找搜索相关的
var allClasses = Object.keys(ObjC.classes);
var candidates = [];

allClasses.forEach(function(clsName) {
    if (clsName.indexOf("Search") !== -1 || 
        clsName.indexOf("Tiku") !== -1 || 
        clsName.indexOf("Recognize") !== -1 ||
        clsName.indexOf("soti") !== -1 ||
        clsName.indexOf("SOTI") !== -1 ||
        clsName.indexOf("Camera") !== -1) {
        candidates.push(clsName);
    }
});

log("候选类: " + candidates.join(", "));

var hooked = false;

candidates.forEach(function(clsName) {
    try {
        var cls = ObjC.classes[clsName];
        if (!cls) return;
        
        // 遍历方法
        var methods = cls.$ownMethods;
        
        methods.forEach(function(methodName) {
            try {
                // Hook searchTimuWithLCS:q:topN:callback:
                if (methodName.indexOf("searchTimuWithLCS") !== -1) {
                    var impl = cls[methodName].implementation;
                    
                    Interceptor.attach(impl, {
                        onEnter: function(args) {
                            // args[0] = self, args[1] = _cmd, args[2] = question, args[3] = topN, args[4] = callback
                            var self = new ObjC.Object(args[0]);
                            var question = new ObjC.Object(args[2]).toString();
                            var callback = args[4];
                            
                            log(">>> searchTimuWithLCS: q=" + question);
                            
                            // 保存原始callback，替换成我们的
                            this.originalCallback = callback;
                            this.question = question;
                            
                            // 替换callback参数
                            var wrapped = wrapCallback(callback, question);
                            if (wrapped) {
                                args[4] = wrapped;
                            }
                        }
                    });
                    
                    log("✓ Hook: " + clsName + "." + methodName);
                    hooked = true;
                }
                
                // Hook searchNetTikus:callback:
                if (methodName.indexOf("searchNetTikus") !== -1) {
                    var impl = cls[methodName].implementation;
                    
                    Interceptor.attach(impl, {
                        onEnter: function(args) {
                            var self = new ObjC.Object(args[0]);
                            var query = new ObjC.Object(args[2]).toString();
                            var callback = args[3];
                            
                            log(">>> searchNetTikus: q=" + query);
                            
                            var wrapped = wrapCallback(callback, query);
                            if (wrapped) {
                                args[3] = wrapped;
                            }
                        }
                    });
                    
                    log("✓ Hook: " + clsName + "." + methodName);
                    hooked = true;
                }
            } catch (e) {
                // 忽略单个方法的错误
            }
        });
    } catch (e) {
        // 忽略单个类的错误
    }
});

if (!hooked) {
    log("⚠ 未找到目标方法，尝试手动查找...");
    
    // 列出所有包含search的方法
    allClasses.forEach(function(clsName) {
        try {
            var cls = ObjC.classes[clsName];
            var methods = cls.$ownMethods;
            methods.forEach(function(m) {
                if (m.indexOf("search") !== -1 || m.indexOf("Search") !== -1) {
                    log("  发现: " + clsName + "." + m);
                }
            });
        } catch (e) {}
    });
}

log("Hook初始化完成，等待录屏搜题...");
