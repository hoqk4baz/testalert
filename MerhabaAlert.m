#import <UIKit/UIKit.h>
#import <substrate.h>  // Theos/CydiaSubstrate için

// Uygulama tamamen yüklendiğinde çalışır
%hook AppDelegate

- (BOOL)application:(UIApplication *)application 
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    BOOL result = %orig; // Orijinal metodu çalıştır

    // Kısa bir gecikme ile alert göster (UI hazır olsun diye)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Merhaba! 👋"
            message:@"Hoş geldiniz!"
            preferredStyle:UIAlertControllerStyleAlert];

        // Kapat butonu - uygulamayı kapatır
        UIAlertAction *closeAction = [UIAlertAction
            actionWithTitle:@"Kapat"
            style:UIAlertActionStyleDestructive
            handler:^(UIAlertAction *action) {
                exit(0); // Uygulamayı kapat
            }];

        // Devam et butonu (isteğe bağlı)
        UIAlertAction *continueAction = [UIAlertAction
            actionWithTitle:@"Devam Et"
            style:UIAlertActionStyleDefault
            handler:nil];

        [alert addAction:continueAction];
        [alert addAction:closeAction];

        // En üstteki view controller'ı bul ve alert'i göster
        UIViewController *rootVC = application.keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        [rootVC presentViewController:alert animated:YES completion:nil];
    });

    return result;
}

%end
