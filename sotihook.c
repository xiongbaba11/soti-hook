/*
 * 小包搜题 Hook v3 - 最简版
 * 先验证Hook能跑通，不包含网络调用
 * 后续再加DeepSeek
 *
 * 编译: zig cc -target aarch64-ios -dynamiclib -O2 -o sotihook.dylib sotihook.c
 */

#include <objc/runtime.h>
#include <objc/message.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>

/* ==== 原始函数指针 ==== */
typedef id (*Fn3)(id, SEL, id, id, id);
typedef id (*Fn2)(id, SEL, id, id);
static Fn3 fn_LCS = NULL;
static Fn3 fn_Index = NULL;
static Fn2 fn_Net = NULL;

/* ==== 消息发送 ==== */
#define S sel_registerName
#define SEND ((id(*)(id,SEL,...))objc_msgSend)

/* ==== 日志(写文件，因为stderr可能看不到) ==== */
static FILE *g_logfile = NULL;

static void hlog(const char *fmt, ...) {
    if (!g_logfile) {
        /* 写到tmp目录 */
        g_logfile = fopen("/tmp/sotihook.log", "a");
        if (!g_logfile) return;
    }
    va_list ap;
    va_start(ap, fmt);
    fprintf(g_logfile, "[SotiHook] ");
    vfprintf(g_logfile, fmt, ap);
    fprintf(g_logfile, "\n");
    fflush(g_logfile);
    va_end(ap);
}

/* ==== NSString辅助 ==== */
static id ns(const char *s) {
    if (!s) return NULL;
    return SEND(objc_getClass("NSString"), S("stringWithUTF8String:"), s);
}
static const char *cs(id o) {
    if (!o) return NULL;
    return (const char*)SEND(o, S("UTF8String"));
}

/* ==== 检查结果 ==== */
static int has_result(id r) {
    if (!r) return 0;
    Class arr = objc_getClass("NSArray");
    Class dict = objc_getClass("NSDictionary");
    Class str = objc_getClass("NSString");
    if (SEND(r, S("isKindOfClass:"), arr))
        return (int)(long)SEND(r, S("count")) > 0;
    if (SEND(r, S("isKindOfClass:"), dict))
        return (int)(long)SEND(r, S("count")) > 0;
    if (SEND(r, S("isKindOfClass:"), str))
        return (int)(long)SEND(r, S("length")) > 0;
    return 1;
}

/* ==== Hook函数 ==== */
static id hook_LCS(id self, SEL _cmd, id q, id topN, id cb) {
    const char *qs = cs(q);
    hlog("searchTimuWithLCS: %s", qs ? qs : "(nil)");
    
    id result = fn_LCS(self, _cmd, q, topN, cb);
    
    if (has_result(result)) {
        hlog("-> 题库命中");
    } else {
        hlog("-> 题库未命中");
        /* TODO: 调DeepSeek API */
    }
    return result;
}

static id hook_Net(id self, SEL _cmd, id q, id cb) {
    const char *qs = cs(q);
    hlog("searchNetTikus: %s", qs ? qs : "(nil)");
    
    id result = fn_Net(self, _cmd, q, cb);
    
    if (has_result(result)) {
        hlog("-> 在线命中");
    } else {
        hlog("-> 在线未命中");
    }
    return result;
}

/* ==== 入口 ==== */
__attribute__((constructor))
static void init(void) {
    hlog("========================================");
    hlog("Hook v3 加载成功!");
    hlog("========================================");
    
    unsigned int cnt = 0;
    Class *clss = objc_copyClassList(&cnt);
    hlog("总类数: %u", cnt);
    
    int found = 0;
    for (unsigned int i = 0; i < cnt; i++) {
        const char *n = class_getName(clss[i]);
        
        /* 过滤 */
        if (!strstr(n, "Search") && !strstr(n, "Tiku") && !strstr(n, "Recognize") &&
            !strstr(n, "soti") && !strstr(n, "SOTI") && !strstr(n, "Camera"))
            continue;
        
        hlog("检查类: %s", n);
        
        unsigned int mc = 0;
        Method *ms = class_copyMethodList(clss[i], &mc);
        if (!ms) continue;
        
        for (unsigned int j = 0; j < mc; j++) {
            const char *sn = sel_getName(method_getName(ms[j]));
            
            if (strstr(sn, "searchTimuWithLCS") && !fn_LCS) {
                fn_LCS = (Fn3)method_getImplementation(ms[j]);
                method_setImplementation(ms[j], (IMP)hook_LCS);
                hlog("  ✓ Hook: %s", sn);
                found++;
            }
            if (strstr(sn, "searchNetTikus") && !fn_Net) {
                fn_Net = (Fn2)method_getImplementation(ms[j]);
                method_setImplementation(ms[j], (IMP)hook_Net);
                hlog("  ✓ Hook: %s", sn);
                found++;
            }
        }
        free(ms);
    }
    free(clss);
    
    if (!found) hlog("⚠ 未找到目标方法!");
    else hlog("Hook就绪 (%d个方法)", found);
}
