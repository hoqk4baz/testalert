#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static IMP original_didFinishLaunching;

static BOOL hooked_didFinishLaunching(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    BOOL result = ((BOOL(*)(id, SEL, UIApplication*, NSDictionary*))original_didFinishLaunching)(self, _cmd, application, launchOptions);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Merhaba! 👋"
            message:@"Hoş geldiniz!"
            preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *closeAction = [UIAlertAction
            actionWithTitle:@"Kapat"
            style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *action) {
                exit(0);
            }];

        UIAlertAction *continueAction = [UIAlertAction
            actionWithTitle:@"Devam Et"
            style:UIAlertActionStyleDefault
            handler:nil];

        [alert addAction:continueAction];
        [alert addAction:closeAction];

        UIViewController *rootVC = application.keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        [rootVC presentViewController:alert animated:YES completion:nil];
    });

    return result;
}

__attribute__((constructor))
static void initialize() {
    Class appDelegateClass = NSClassFromString(@"AppDelegate");
    if (!appDelegateClass) return;

    SEL sel = @selector(application:didFinishLaunchingWithOptions:);
    Method method = class_getInstanceMethod(appDelegateClass, sel);
    if (!method) return;

    original_didFinishLaunching = method_getImplementation(method);
    method_setImplementation(method, (IMP)hooked_didFinishLaunching);
}
