#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <dlfcn.h>
#import <objc/runtime.h>

static NSString *randomUUID(void) {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomString(int length) {
    NSString *letters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:length];
    for (int i = 0; i < length; i++) {
        [s appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)letters.length)]];
    }
    return s;
}

// ====================== FLOATING BUBBLE ======================
@interface DeviceSpooferBubble : NSObject
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIButton *bubbleButton;
@property (nonatomic, strong) UIViewController *panelVC;
@end

@implementation DeviceSpooferBubble

+ (instancetype)shared {
    static DeviceSpooferBubble *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[DeviceSpooferBubble alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self createBubble];
    }
    return self;
}

- (void)createBubble {
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
    self.window.windowLevel = UIWindowLevelStatusBar + 1;
    self.window.backgroundColor = [UIColor clearColor];
    
    self.bubbleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.bubbleButton.frame = CGRectMake(0, 0, 60, 60);
    self.bubbleButton.backgroundColor = [UIColor systemBlueColor];
    self.bubbleButton.layer.cornerRadius = 30;
    self.bubbleButton.layer.shadowColor = [UIColor blackColor].CGColor;
    self.bubbleButton.layer.shadowOffset = CGSizeMake(0, 2);
    self.bubbleButton.layer.shadowOpacity = 0.5;
    [self.bubbleButton setTitle:@"🔄" forState:UIControlStateNormal];
    self.bubbleButton.titleLabel.font = [UIFont systemFontOfSize:30];
    
    [self.bubbleButton addTarget:self action:@selector(showPanel) forControlEvents:UIControlEventTouchUpInside];
    
    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    [vc.view addSubview:self.bubbleButton];
    self.window.rootViewController = vc;
    self.window.hidden = NO;
    
    // Draggable yap
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.bubbleButton addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self.window];
    CGPoint center = self.bubbleButton.center;
    center.x += translation.x;
    center.y += translation.y;
    self.bubbleButton.center = center;
    [pan setTranslation:CGPointZero inView:self.window];
}

- (void)showPanel {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Device Spoofer"
                                                                   message:[self getCurrentDeviceInfo]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Değiştir" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self resetAndSpoof];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (NSString *)getCurrentDeviceInfo {
    UIDevice *device = [UIDevice currentDevice];
    ASIdentifierManager *idm = [ASIdentifierManager sharedManager];
    
    return [NSString stringWithFormat:
            @"IDFV: %@\n"
            @"IDFA: %@\n"
            @"Model: %@\n"
            @"System: %@ %@",
            device.identifierForVendor.UUIDString ?: @"-",
            idm.advertisingIdentifier.UUIDString ?: @"-",
            device.model,
            device.systemName, device.systemVersion];
}

- (void)resetAndSpoof {
    // Uygulama verilerini temizle
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // Cache klasörlerini temizle
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    for (NSString *path in paths) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    
    // Yeni spoof değerleri üret (static'leri resetle)
    [self forceSpoofReset];
    
    // Kullanıcıya bilgi ver ve app'i yeniden başlat
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Başarılı"
                                                                   message:@"Cihaz bilgileri değiştirildi.\nUygulama yeniden başlatılıyor..."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            exit(0); // App'i kapat (yeniden açıldığında yeni ID'lerle gelecek)
        });
    }];
}

- (void)forceSpoofReset {
    // Static değişkenleri sıfırla (sonraki launch'ta yeni değer gelecek)
    NSLog(@"[DeviceSpoofer] All device identifiers reset.");
}

@end

// ====================== SPOOFING HOOK'LAR ======================

%hook UIDevice
- (NSUUID *)identifierForVendor {
    static NSUUID *spoofed = nil;
    if (!spoofed) spoofed = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return spoofed;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    static NSUUID *spoofed = nil;
    if (!spoofed) spoofed = [[NSUUID alloc] initWithUUIDString:randomUUID()];
    return spoofed;
}
- (BOOL)isAdvertisingTrackingEnabled { return YES; }
%end

%hookf(CFStringRef, MGCopyAnswer, CFStringRef key) {
    NSString *k = (__bridge NSString *)key;
    if ([k containsString:@"UniqueDeviceID"]) return (__bridge CFStringRef)randomUUID();
    if ([k containsString:@"SerialNumber"]) return (__bridge CFStringRef)randomString(12);
    return %orig;
}

%ctor {
    NSLog(@"[DeviceSpoofer] ✅ Floating Bubble + Spoofer Loaded!");
    [DeviceSpooferBubble shared];  // Bubble'ı başlat
}
