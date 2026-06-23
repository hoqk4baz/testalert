#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSMutableArray *logs = nil;

static void addLog(NSString *source, NSString *value) {
    if (!value || value.length == 0) return;
    NSArray *stack = [NSThread callStackSymbols];
    NSString *log = [NSString stringWithFormat:@"[%@]\nvalue=%@\n%@",
        source, value,
        [[stack subarrayWithRange:NSMakeRange(0, MIN(6, stack.count))] componentsJoinedByString:@"\n"]
    ];
    [logs addObject:log];
}

// 1. identifierForVendor
static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    IMP orig = class_getMethodImplementation(objc_getClass("UIDevice"), @selector(identifierForVendor));
    NSUUID *result = ((NSUUID*(*)(id,SEL))orig)(self, _cmd);
    addLog(@"IDFV", result.UUIDString);
    return result;
}

// 2. NSUserDefaults
static id (*orig_objectForKey)(id, SEL, NSString*) = NULL;
static id hook_objectForKey(id self, SEL _cmd, NSString *key) {
    id result = orig_objectForKey(self, _cmd, key);
    if ([result isKindOfClass:[NSString class]] && [result length] > 10) {
        addLog([NSString stringWithFormat:@"UserDefaults[%@]", key], result);
    }
    return result;
}

// 3. SecItemCopyMatching
typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef, CFTypeRef*);
static SecItemCopyMatching_t orig_SecItemCopyMatching = NULL;
static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_SecItemCopyMatching(query, result);
    if (status == errSecSuccess && result && *result) {
        NSDictionary *q = (__bridge NSDictionary*)query;
        NSString *service = q[(__bridge id)kSecAttrService] ?: @"?";
        
        if (CFGetTypeID(*result) == CFDictionaryGetTypeID()) {
            NSDictionary *item = (__bridge NSDictionary*)*result;
            NSData *data = item[(__bridge id)kSecValueData];
            if (data) {
                NSString *val = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                addLog([NSString stringWithFormat:@"Keychain[%@]", service], val);
            }
        }
    }
    return status;
}

// 4. NSFileManager - dosyadan okuma
static NSData *(*orig_contentsAtPath)(id, SEL, NSString*) = NULL;
static NSData *hook_contentsAtPath(id self, SEL _cmd, NSString *path) {
    NSData *result = orig_contentsAtPath(self, _cmd, path);
    if (result && path && [path containsString:@"device"]) {
        NSString *val = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
        addLog([NSString stringWithFormat:@"File[%@]", path], val);
    }
    return result;
}

// 5. NSString initWithContentsOfFile
static id (*orig_initWithContentsOfFile)(id, SEL, NSString*) = NULL;
static id hook_initWithContentsOfFile(id self, SEL _cmd, NSString *path) {
    id result = orig_initWithContentsOfFile(self, _cmd, path);
    if (result && path && ([path containsString:@"device"] || [path containsString:@"uuid"] || [path containsString:@"id"])) {
        addLog([NSString stringWithFormat:@"StringFile[%@]", path], result);
    }
    return result;
}

// Alert göster
static void showAlert() {
    UIWindow *window = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            window = ((UIWindowScene *)scene).windows.firstObject;
            break;
        }
    }
    if (!window) return;
    
    NSString *combined = logs.count > 0
        ? [logs componentsJoinedByString:@"\n\n---\n\n"]
        : @"Hiçbir kaynak tespit edilmedi";
    
    [UIPasteboard generalPasteboard].string = combined;
    
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Device ID Kaynakları"
        message:[NSString stringWithFormat:@"%lu kaynak bulundu\nPanoya kopyalandı", (unsigned long)logs.count]
        preferredStyle:UIAlertControllerStyleAlert
    ];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

@interface DeviceLogger : NSObject
@end

@implementation DeviceLogger

+ (void)load {
    logs = [NSMutableArray array];
    
    // 1. IDFV
    Method m1 = class_getInstanceMethod(objc_getClass("UIDevice"), @selector(identifierForVendor));
    if (m1) method_setImplementation(m1, (IMP)hook_identifierForVendor);
    
    // 2. NSUserDefaults
    Method m2 = class_getInstanceMethod(objc_getClass("NSUserDefaults"), @selector(objectForKey:));
    if (m2) {
        orig_objectForKey = (id(*)(id,SEL,NSString*))method_getImplementation(m2);
        method_setImplementation(m2, (IMP)hook_objectForKey);
    }
    
    // 3. Keychain
    rebind_symbols((struct rebinding[1]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void**)&orig_SecItemCopyMatching}
    }, 1);
    
    // 4. NSFileManager
    Method m4 = class_getInstanceMethod(objc_getClass("NSFileManager"), @selector(contentsAtPath:));
    if (m4) {
        orig_contentsAtPath = (NSData*(*)(id,SEL,NSString*))method_getImplementation(m4);
        method_setImplementation(m4, (IMP)hook_contentsAtPath);
    }
    
    // 5. NSString initWithContentsOfFile
    Method m5 = class_getInstanceMethod(objc_getClass("NSString"), @selector(initWithContentsOfFile:));
    if (m5) {
        orig_initWithContentsOfFile = (id(*)(id,SEL,NSString*))method_getImplementation(m5);
        method_setImplementation(m5, (IMP)hook_initWithContentsOfFile);
    }
    
    // 8 saniye bekle - uygulama her şeyi yüklesin
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            showAlert();
        });
    });
}

@end
