#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#include "fishhook.h"

static NSMutableArray *foundLogs = nil;
static NSString *targetPrefix = @"77bc647f"; // ilk 8 char yeterli

// NSString isEqualToString hook - bu değerin nerede karşılaştırıldığını bul
typedef BOOL (*isEqual_t)(id, SEL, id);
static isEqual_t orig_isEqual = NULL;

static BOOL hook_isEqual(id self, SEL _cmd, id other) {
    if ([self isKindOfClass:[NSString class]] && [other isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)self;
        NSString *o = (NSString *)other;
        if ([s hasPrefix:targetPrefix] || [o hasPrefix:targetPrefix]) {
            NSString *trace = [[NSThread callStackSymbols] componentsJoinedByString:@"\n"];
            NSString *log = [NSString stringWithFormat:@"isEqual:\nself=%@\nother=%@\n\nStack:\n%@", s, o, trace];
            [foundLogs addObject:log];
        }
    }
    return orig_isEqual(self, _cmd, other);
}

// NSString stringWithFormat hook - bu değerin nerede üretildiğini bul  
typedef NSString* (*stringWithFormat_t)(id, SEL, NSString*, ...);

// NSMutableURLRequest setValue:forHTTPHeaderField: hook - header set edilirken yakala
static void hook_setValueForHTTPHeaderField(id self, SEL _cmd, NSString *value, NSString *field) {
    if ([field isEqualToString:@"deviceId"] || [value hasPrefix:targetPrefix]) {
        NSString *trace = [[NSThread callStackSymbols] componentsJoinedByString:@"\n"];
        NSString *log = [NSString stringWithFormat:@"[HEADER SET]\nfield=%@\nvalue=%@\n\nStack:\n%@", field, value, trace];
        [foundLogs addObject:log];
    }
    
    // orijinali çağır
    IMP orig = class_getMethodImplementation(
        objc_getClass("NSMutableURLRequest"),
        @selector(setValue:forHTTPHeaderField:)
    );
    ((void(*)(id,SEL,NSString*,NSString*))orig)(self, _cmd, value, field);
}

@interface DeviceTracer : NSObject
@end

@implementation DeviceTracer

+ (void)load {
    foundLogs = [NSMutableArray array];
    
    // NSMutableURLRequest hook - deviceId header'ı set edilirken yakala
    Method m = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setValue:forHTTPHeaderField:)
    );
    if (m) method_setImplementation(m, (IMP)hook_setValueForHTTPHeaderField);
    
    // 5 saniye bekle - uygulama istek atsın
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
            
            NSString *logs = foundLogs.count > 0
                ? [foundLogs componentsJoinedByString:@"\n\n---\n\n"]
                : @"Henüz tespit edilmedi - daha uzun bekle";
            
            // Alert çok uzun olabilir - UIPasteboard'a kopyala
            [UIPasteboard generalPasteboard].string = logs;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Device ID Tracer"
                message:[NSString stringWithFormat:@"%lu log bulundu.\nPanoya kopyalandı.", (unsigned long)foundLogs.count]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
