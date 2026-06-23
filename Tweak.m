#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSMutableArray *foundLogs = nil;
static NSString *targetValue = @"77bc647f";

static void (*orig_setValue)(id, SEL, NSString*, NSString*) = NULL;

static void hook_setValue(id self, SEL _cmd, NSString *value, NSString *field) {
    @try {
        if (value && [value hasPrefix:targetValue]) {
            NSArray *stack = [NSThread callStackSymbols];
            NSString *log = [NSString stringWithFormat:@"field=%@\nvalue=%@\n%@",
                field, value,
                [stack componentsJoinedByString:@"\n"]
            ];
            [foundLogs addObject:log];
        }
    } @catch (NSException *e) {}
    
    orig_setValue(self, _cmd, value, field);
}

@interface DeviceTracer : NSObject
@end

@implementation DeviceTracer

+ (void)load {
    foundLogs = [NSMutableArray array];
    
    Method m = class_getInstanceMethod(
        objc_getClass("NSMutableURLRequest"),
        @selector(setValue:forHTTPHeaderField:)
    );
    
    if (m) {
        orig_setValue = (void(*)(id,SEL,NSString*,NSString*))method_getImplementation(m);
        method_setImplementation(m, (IMP)hook_setValue);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)),
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
                : @"Tespit edilemedi";
            
            [UIPasteboard generalPasteboard].string = logs;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:@"Tracer"
                message:[NSString stringWithFormat:@"%lu log - panoya kopyalandı", (unsigned long)foundLogs.count]
                preferredStyle:UIAlertControllerStyleAlert
            ];
            [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:nil]];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        });
    });
}

@end
