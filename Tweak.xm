#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <WebKit/WebKit.h>

#pragma mark - =====================
#pragma mark DEVICE ID MANAGER
#pragma mark =====================

@interface DIManager : NSObject
@property (nonatomic, strong) NSString *fakeIDFV;
@property (nonatomic, strong) NSString *fakeIDFA;
+ (instancetype)shared;
- (void)generate;
@end

@implementation DIManager

+ (instancetype)shared {
    static DIManager *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = [DIManager new];
        [m generate];
    });
    return m;
}

- (NSString *)uuid {
    return [[NSUUID UUID] UUIDString];
}

- (void)generate {
    self.fakeIDFV = [self uuid];
    self.fakeIDFA = [self uuid];
}

@end

#pragma mark - =====================
#pragma mark RESET ENGINE (FULL WIPE)
#pragma mark =====================

static void fullAppReset(void) {

    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *home = NSHomeDirectory();

    NSArray *targets = @[
        home,
        [home stringByAppendingPathComponent:@"Documents"],
        [home stringByAppendingPathComponent:@"Library"],
        [home stringByAppendingPathComponent:@"Library/Caches"],
        NSTemporaryDirectory()
    ];

    for (NSString *path in targets) {

        NSArray *items = [fm contentsOfDirectoryAtPath:path error:nil];

        for (NSString *item in items) {
            NSString *full = [path stringByAppendingPathComponent:item];
            [fm removeItemAtPath:full error:nil];
        }
    }

    // UserDefaults
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:
     [[NSBundle mainBundle] bundleIdentifier]];

    [[NSUserDefaults standardUserDefaults] synchronize];

    // URLCache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];

    // Cookies
    NSHTTPCookieStorage *cookie = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *c in cookie.cookies) {
        [cookie deleteCookie:c];
    }

    // WKWebView data (modern apps için önemli)
    if (@available(iOS 9.0, *)) {
        NSSet *types = [NSSet setWithArray:@[
            WKWebsiteDataTypeCookies,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeWebSQLDatabases
        ]];

        [[WKWebsiteDataStore defaultDataStore]
         removeDataOfTypes:types
         modifiedSince:[NSDate dateWithTimeIntervalSince1970:0]
         completionHandler:^{}];
    }
}

#pragma mark - =====================
#pragma mark HOOKS
#pragma mark =====================

%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:
            [DIManager shared].fakeIDFV];
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:
            [DIManager shared].fakeIDFA];
}

%end

#pragma mark - =====================
#pragma mark REAL + FAKE INFO
#pragma mark =====================

static NSString *realInfo(void) {
    UIDevice *d = UIDevice.currentDevice;
    ASIdentifierManager *ad = [ASIdentifierManager sharedManager];

    return [NSString stringWithFormat:
@"REAL DEVICE\n\nModel: %@\nSystem: %@ %@\nIDFV: %@\nIDFA: %@",
d.model,
d.systemName,
d.systemVersion,
d.identifierForVendor.UUIDString,
ad.advertisingIdentifier.UUIDString];
}

static NSString *fakeInfo(void) {
    DIManager *m = [DIManager shared];

    return [NSString stringWithFormat:
@"FAKE DEVICE\n\nIDFV: %@\nIDFA: %@",
m.fakeIDFV,
m.fakeIDFA];
}

#pragma mark - =====================
#pragma mark TOP VC
#pragma mark =====================

static UIViewController *topVC(void) {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w.rootViewController;
    }
    return nil;
}

#pragma mark - =====================
#pragma mark FLOATING UI
#pragma mark =====================

@interface Bubble : NSObject
@property UIView *bubble;
@property BOOL dragging;
@end

@implementation Bubble

+ (instancetype)shared {
    static Bubble *b;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        b = [Bubble new];
    });
    return b;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup {

    UIWindow *w = UIApplication.sharedApplication.windows.firstObject;

    self.bubble = [[UIView alloc] initWithFrame:CGRectMake(180, 250, 80, 80)];
    self.bubble.backgroundColor =
    [[UIColor systemBlueColor] colorWithAlphaComponent:0.9];

    self.bubble.layer.cornerRadius = 40;

    UILabel *l = [[UILabel alloc] initWithFrame:self.bubble.bounds];
    l.text = @"ID";
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = UIColor.whiteColor;
    l.font = [UIFont boldSystemFontOfSize:20];

    [self.bubble addSubview:l];

    UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(open)];

    [self.bubble addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    [self.bubble addGestureRecognizer:pan];

    [w addSubview:self.bubble];
}

- (void)move:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.bubble.superview];
    self.bubble.center = CGPointMake(self.bubble.center.x + t.x,
                                     self.bubble.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.bubble.superview];
}

- (void)open {

    DIManager *m = [DIManager shared];

    NSString *msg = [NSString stringWithFormat:@"%@\n\n%@", realInfo(), fakeInfo()];

    UIAlertController *a =
    [UIAlertController alertControllerWithTitle:@"Device Panel"
                                        message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"🔄 Regenerate IDs"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
        [m generate];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"🧹 RESET APP (FULL WIPE)"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * _Nonnull action) {
        fullAppReset();
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Close"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

    [topVC() presentViewController:a animated:YES completion:nil];
}

@end

#pragma mark - =====================
#pragma mark INIT
#pragma mark =====================

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [Bubble shared];
    });
}
