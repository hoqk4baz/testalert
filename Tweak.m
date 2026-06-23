#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSMutableArray *logs = nil;

static void addLog(NSString *msg) {
    @synchronized(logs) {
        [logs addObject:msg];
    }
}

// 1. IDFV
static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    addLog(@"IDFV çağrıldı");
    IMP orig = class_getMethodImplementation(objc_getClass("UIDevice"), @selector(identifierForVendor));
    return ((NSUUID*(*)(id,SEL))orig)(self, _cmd);
}

// 2. Keychain
typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef, CFTypeRef*);
static SecItemCopyMatching_t orig_SecItemCopyMatching = NULL;
static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    @try {
        NSDictionary *q = (__bridge NSDictionary*)query;
        NSString *service = q[(__bridge id)kSecAttrService] ?: @"?";
        addLog([NSString stringWithFormat:@"Keychain okundu: %@", service]);
    } @catch(NSException *e) {}
    return orig_SecItemCopyMatching(query, result);
}

// 3. NSFileManager
static NSData *(*orig_contentsAtPath)(id, SEL, NSString*) = NULL;
static NSData *hook_contentsAtPath(id self, SEL _cmd, NSString *path) {
    @try {
        addLog([NSString stringWithFormat:@"File okundu: %@", path.lastPathComponent]);
    } @catch(NSException *e) {}
    return orig_contentsAtPath(self, _cmd, path);
}

// 4. NSUserDefaults
static id (*orig_objectForKey)(id, SEL, NSString*) = NULL;
static id hook_objectForKey(id self, SEL _cmd, NSString *key) {
    @try {
        addLog([NSString stringWithFormat:@"UserDefaults: %@", key]);
    } @catch(NSException *e) {}
    return orig_objectForKey(self, _cmd, key);
}

@interface DeviceLogger : NSObject
@end

@implementation DeviceLogger

+ (void)load {
    logs = [NSMutableArray array];
    
    // IDFV
    Method m1 = class_getInstanceMethod(objc_getClass("UIDevice"), @selector(identifierForVendor));
    if (m1) method_setImplementation(m1, (IMP)hook_identifierForVendor);
    
    // Keychain
    rebind_symbols((struct rebinding[1]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void**)&orig_SecItemCopyMatching}
    }, 1);
    
    // NSFileManager
    Method m3 = class_getInstanceMethod(objc_getClass("NSFileManager"), @selector(contentsAtPath:));
    if (m3) {
        orig_contentsAtPath = (NSData*(*)(id,SEL,NSString*))method_getImplementation(m3);
        method_setImplementation(m3, (IMP)hook_contentsAtPath);
    }
    
    // NSUserDefaults
    Method m4 = class_getInstanceMethod(objc_getClass("NSUserDefaults"), @selector(objectForKey:));
    if (m4) {
        orig_objectForKey = (id(*)(id,SEL,NSString*))method_getImplementation(m4);
        method_setImplementation(m4, (IMP)hook_objectForKey);
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
            
            // Sadece unique loglar
            NSOrderedSet *unique = [NSOrderedSet orderedSetWithArray:logs];
            NSString *combined = unique.count > 0
                ? [[unique array] componentsJoinedByString:@"\n"]
                : @"Tespit edilemedi";
            
            [UIPasteboard generalPasteboard].string = combined;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Hook Tetiklenenler"
                message:[NSString stringWithFormat:@"%lu unique\nPanoya kopyalandı", (unsigned long)unique.count]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
