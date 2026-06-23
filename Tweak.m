#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSMutableArray *logs = nil;

// 1. IDFV
static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    [logs addObject:@"IDFV"];
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
        [logs addObject:[NSString stringWithFormat:@"Keychain: %@", service]];
    } @catch(NSException *e) {}
    return orig_SecItemCopyMatching(query, result);
}

@interface DeviceLogger : NSObject
@end

@implementation DeviceLogger

+ (void)load {
    logs = [NSMutableArray array];
    
    Method m1 = class_getInstanceMethod(objc_getClass("UIDevice"), @selector(identifierForVendor));
    if (m1) method_setImplementation(m1, (IMP)hook_identifierForVendor);
    
    rebind_symbols((struct rebinding[1]){
        {"SecItemCopyMatching", hook_SecItemCopyMatching, (void**)&orig_SecItemCopyMatching}
    }, 1);
    
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
            
            NSOrderedSet *unique = [NSOrderedSet orderedSetWithArray:logs];
            NSString *combined = [[unique array] componentsJoinedByString:@"\n"] ?: @"Tespit edilemedi";
            [UIPasteboard generalPasteboard].string = combined;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Hook Log"
                message:[NSString stringWithFormat:@"%lu log\nPanoya kopyalandı", unique.count]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
