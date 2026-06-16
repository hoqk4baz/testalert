#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

#pragma mark - =====================
#pragma mark ID MODES
#pragma mark =====================

typedef NS_ENUM(NSInteger, IDMode) {
    IDModeReal = 0,
    IDModeFake,
    IDModeRandom
};

@interface DIEngine : NSObject
@property (nonatomic, strong) NSString *deviceID;
@property (nonatomic, assign) IDMode mode;
+ (instancetype)shared;
- (void)regen;
@end

@implementation DIEngine

+ (instancetype)shared {
    static DIEngine *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = [DIEngine new];
        d.mode = IDModeFake;
        [d regen];
    });
    return d;
}

- (NSString *)uuid {
    return [[NSUUID UUID] UUIDString];
}

- (void)regen {

    switch (self.mode) {

        case IDModeReal:
            self.deviceID = [[UIDevice currentDevice].identifierForVendor UUIDString];
            break;

        case IDModeFake:
            self.deviceID = @"FAKE-DEVICE-ID-0000-STATIC";
            break;

        case IDModeRandom:
            self.deviceID = [self uuid];
            break;
    }
}

@end

#pragma mark - =====================
#pragma mark HOOKS
#pragma mark =====================

%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:[DIEngine shared].deviceID];
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:[DIEngine shared].deviceID];
}

%end

%hook NSUUID

- (NSString *)UUIDString {
    return [DIEngine shared].deviceID;
}

%end

#pragma mark - =====================
#pragma mark SAFE WINDOW
#pragma mark =====================

static UIWindow *getWindow(void) {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) return w;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

#pragma mark - =====================
#pragma mark RESET
#pragma mark =====================

static void fullReset(void) {
    [[DIEngine shared] regen];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:
     [[NSBundle mainBundle] bundleIdentifier]];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

#pragma mark - =====================
#pragma mark FLOATING PANEL
#pragma mark =====================

@interface Bubble : NSObject
@property UIView *view;
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

    UIWindow *w = getWindow();

    self.view = [[UIView alloc] initWithFrame:CGRectMake(120, 200, 70, 70)];
    self.view.backgroundColor = UIColor.systemBlueColor;
    self.view.layer.cornerRadius = 35;

    UILabel *l = [[UILabel alloc] initWithFrame:self.view.bounds];
    l.text = @"ID";
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = UIColor.whiteColor;
    l.font = [UIFont boldSystemFontOfSize:18];
    [self.view addSubview:l];

    UITapGestureRecognizer *tap =
    [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(open)];
    [self.view addGestureRecognizer:tap];

    UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    [self.view addGestureRecognizer:pan];

    [w addSubview:self.view];
}

- (void)move:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view.superview];
    self.view.center = CGPointMake(self.view.center.x + t.x,
                                   self.view.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.view.superview];
}

- (void)open {

    DIEngine *e = [DIEngine shared];

    NSString *msg = [NSString stringWithFormat:
                     @"MODE: %ld\nDEVICE ID:\n%@",
                     (long)e.mode, e.deviceID];

    UIAlertController *a =
    [UIAlertController alertControllerWithTitle:@"Identity Panel"
                                        message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"Real Mode"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
        e.mode = IDModeReal;
        [e regen];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Fake Mode"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
        e.mode = IDModeFake;
        [e regen];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Random Mode"
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * _Nonnull action) {
        e.mode = IDModeRandom;
        [e regen];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Reset App"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * _Nonnull action) {
        fullReset();
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Close"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

    [[UIApplication sharedApplication].keyWindow.rootViewController
     presentViewController:a animated:YES completion:nil];
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
