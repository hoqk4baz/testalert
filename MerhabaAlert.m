#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void showAlert() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        UIWindow *window = nil;
        
        // iOS 13+ sahne bazlı pencere bul
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }
        }
        
        // Fallback: eski yöntem
        if (!window) {
            window = [UIApplication sharedApplication].keyWindow;
        }
        
        if (!window) return;

        UIViewController *rootVC = window.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }

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
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

// UIApplication'ın applicationDidBecomeActive metodunu hook'la
// Bu tüm uygulamalarda çalışır
static IMP original_applicationDidBecomeActive;
static BOOL alertShown = NO;

static void hooked_applicationDidBecomeActive(id self, SEL _cmd, UIApplication *application) {
    ((void(*)(id, SEL, UIApplication*))original_applicationDidBecomeActive)(self, _cmd, application);
    
    if (!alertShown) {
        alertShown = YES;
        showAlert();
    }
}

__attribute__((constructor))
static void initialize() {
    // Tüm UIApplicationDelegate subclass'larını tara
    unsigned int classCount = 0;
    Class *classes = objc_copyClassList(&classCount);
    
    for (unsigned int i = 0; i < classCount; i++) {
        Class cls = classes[i];
        if (class_conformsToProtocol(cls, @protocol(UIApplicationDelegate))) {
            SEL sel = @selector(applicationDidBecomeActive:);
            Method method = class_getInstanceMethod(cls, sel);
            if (method) {
                original_applicationDidBecomeActive = method_getImplementation(method);
                method_setImplementation(method, (IMP)hooked_applicationDidBecomeActive);
                break;
            }
        }
    }
    
    free(classes);
}
