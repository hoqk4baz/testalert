#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSMutableArray *logs = nil;

static void addLog(NSString *source, NSString *value) {
    if (!value || value.length < 8) return;
    @synchronized(logs) {
        [logs addObject:[NSString stringWithFormat:@"[%@] %@", source, value]];
    }
}

// IDFV
static NSUUID *hook_identifierForVendor(id self, SEL _cmd) {
    IMP orig = class_getMethodImplementation(objc_getClass("UIDevice"), @selector(identifierForVendor));
    NSUUID *result = ((NSUUID*(*)(id,SEL))orig)(self, _cmd);
    addLog(@"IDFV", result.UUIDString);
    return result;
}

// Keychain
typedef OSStatus (*SecItemCopyMatching_t)(CFDictionaryRef, CFTypeRef*);
static SecItemCopyMatching_t orig_SecItemCopyMatching = NULL;

static OSStatus hook_SecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
    OSStatus status = orig_SecItemCopyMatching(query, result);
    @try {
        if (status == errSecSuccess && result && *result) {
            NSDictionary *q = (__bridge NSDictionary*)query;
            NSString *service = q[(__bridge id)kSecAttrService] ?: @"?";
            if (CFGetTypeID(*result) == CFDictionaryGetTypeID()) {
                NSData *data = ((__bridge NSDictionary*)*result)[(__bridge id)kSecValueData];
                if (data) {
                    NSString *val = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    addLog([NSString stringWithFormat:@"Keychain[%@]", service], val);
                }
            } else if (CFGetTypeID(*result) == CFArrayGetTypeID()) {
                for (NSDictionary *item in (__bridge NSArray*)*result) {
                    NSData *data = item[(__bridge id)kSecValueData];
                    NSString *s = item[(__bridge id)kSecAttrService] ?: service;
                    if (data) {
                        NSString *val = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        addLog([NSString stringWithFormat:@"Keychain[%@]", s], val);
                    }
                }
            }
        }
    } @catch(NSException *e) {}
    return status;
}

// NSFileManager - crash yapmaz çünkü path filtresi var
static NSData *(*orig_contentsAtPath)(id, SEL, NSString*) = NULL;
static NSData *hook_contentsAtPath(id self, SEL _cmd, NSString *path) {
    NSData *result = orig_contentsAtPath(self, _cmd, path);
    @try {
        if (result && path) {
            NSString *lower = path.lowercaseString;
            if ([lower containsString:@"uuid"] ||
                [lower containsString:@"device"] ||
                [lower containsString:@"udid"] ||
                [lower containsString:@"ident"]) {
                NSString *val = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
                if (val) addLog([NSString stringWithFormat:@"File[%@]", path.lastPathComponent], val);
            }
        }
    } @catch(NSException *e) {}
    return result;
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
    
    Method m4 = class_getInstanceMethod(objc_getClass("NSFileManager"), @selector(contentsAtPath:));
    if (m4) {
        orig_contentsAtPath = (NSData*(*)(id,SEL,NSString*))method_getImplementation(m4);
        method_setImplementation(m4, (IMP)hook_contentsAtPath);
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
            
            NSString *combined = logs.count > 0
                ? [logs componentsJoinedByString:@"\n"]
                : @"Tespit edilemedi";
            
            [UIPasteboard generalPasteboard].string = combined;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Device ID Kaynakları"
                message:[NSString stringWithFormat:@"%lu kaynak\nPanoya kopyalandı", (unsigned long)logs.count]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
