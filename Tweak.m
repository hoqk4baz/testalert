#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSMutableArray *logs = nil;
static NSString *target = @"77bc647f";

// SecItemCopyMatching - Keychain okumalarını yakala
typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef, CFTypeRef *);
static SecItemCopyMatching_t orig_CopyMatching = NULL;

static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_CopyMatching(query, result);
    
    if (status == errSecSuccess && result && *result) {
        void (^checkItem)(NSDictionary *) = ^(NSDictionary *item) {
            NSData *valueData = item[(__bridge id)kSecValueData];
            if (!valueData) return;
            NSString *value = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
            if (!value) value = [valueData base64EncodedStringWithOptions:0];
            if (value && [value containsString:target]) {
                NSString *service = item[(__bridge id)kSecAttrService] ?: @"-";
                NSString *account = item[(__bridge id)kSecAttrAccount] ?: @"-";
                NSString *log = [NSString stringWithFormat:@"[KEYCHAIN HIT]\nservice=%@\naccount=%@\nvalue=%@", service, account, value];
                [logs addObject:log];
            }
        };
        
        if (CFGetTypeID(*result) == CFDictionaryGetTypeID()) {
            checkItem((__bridge NSDictionary *)*result);
        } else if (CFGetTypeID(*result) == CFArrayGetTypeID()) {
            for (NSDictionary *item in (__bridge NSArray *)*result) {
                if ([item isKindOfClass:[NSDictionary class]]) checkItem(item);
            }
        }
    }
    return status;
}

// NSUserDefaults objectForKey hook
static id (*orig_objectForKey)(id, SEL, NSString *) = NULL;
static id hook_objectForKey(id self, SEL _cmd, NSString *key) {
    id result = orig_objectForKey(self, _cmd, key);
    if ([result isKindOfClass:[NSString class]] && [result containsString:target]) {
        NSString *log = [NSString stringWithFormat:@"[USERDEFAULTS HIT]\nkey=%@\nvalue=%@", key, result];
        [logs addObject:log];
    }
    return result;
}

// NSString stringByAppendingString - concatenation sırasında yakala
static NSString *(*orig_stringByAppending)(id, SEL, NSString *) = NULL;
static NSString *hook_stringByAppending(id self, SEL _cmd, NSString *str) {
    NSString *result = orig_stringByAppending(self, _cmd, str);
    if ([result containsString:target]) {
        NSString *log = [NSString stringWithFormat:@"[STRING BUILD]\nself=%@\nappend=%@\nresult=%@\n%@",
            self, str, result,
            [[NSThread callStackSymbols] componentsJoinedByString:@"\n"]
        ];
        [logs addObject:log];
    }
    return result;
}

@interface SourceTracer : NSObject
@end

@implementation SourceTracer

+ (void)load {
    logs = [NSMutableArray array];
    
    // Keychain hook
    rebind_symbols((struct rebinding[1]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void **)&orig_CopyMatching},
    }, 1);
    
    // NSUserDefaults hook
    Method m1 = class_getInstanceMethod(objc_getClass("NSUserDefaults"), @selector(objectForKey:));
    if (m1) {
        orig_objectForKey = (id(*)(id,SEL,NSString*))method_getImplementation(m1);
        method_setImplementation(m1, (IMP)hook_objectForKey);
    }
    
    // NSString hook
    Method m2 = class_getInstanceMethod(objc_getClass("NSString"), @selector(stringByAppendingString:));
    if (m2) {
        orig_stringByAppending = (NSString*(*)(id,SEL,NSString*))method_getImplementation(m2);
        method_setImplementation(m2, (IMP)hook_stringByAppending);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            
            UIWindow *window = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    window = ((UIWindowScene *)scene).windows.firstObject;
                    break;
                }
            }
            if (!window) return;
            
            NSString *output = logs.count > 0
                ? [logs componentsJoinedByString:@"\n\n---\n\n"]
                : @"Kaynak bulunamadı";
            
            [UIPasteboard generalPasteboard].string = output;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Source Tracer"
                message:[NSString stringWithFormat:@"%lu hit - panoya kopyalandı", (unsigned long)logs.count]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
