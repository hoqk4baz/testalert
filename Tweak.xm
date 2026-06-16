#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>

#pragma mark - Fake Storage

static NSString *kIDFA = @"fake.idfa";
static NSString *kIDFV = @"fake.idfv";

static NSString *randUUID(void) {
    return [[NSUUID UUID] UUIDString];
}

static NSString *getFake(NSString *key) {
    NSString *v = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (!v) {
        v = randUUID();
        [[NSUserDefaults standardUserDefaults] setObject:v forKey:key];
    }
    return v;
}

static void regenerateIDs(void) {
    [[NSUserDefaults standardUserDefaults] setObject:randUUID() forKey:kIDFA];
    [[NSUserDefaults standardUserDefaults] setObject:randUUID() forKey:kIDFV];
}

#pragma mark - Safe Window Helper

static UIViewController *topVC(void) {
    UIWindow *window = nil;

    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w.isKeyWindow) {
            window = w;
            break;
        }
    }

    return window.rootViewController;
}

#pragma mark - Hooks (NO SUBSTRATE NEEDED)

%hook UIDevice

- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:getFake(kIDFV)];
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:getFake(kIDFA)];
}

%end

#pragma mark - Floating Bubble

@interface SpooferBubble : NSObject
@property UIWindow *window;
@property UIButton *btn;
@property BOOL dragging;
@end

@implementation SpooferBubble

+ (instancetype)shared {
    static SpooferBubble *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        s = [SpooferBubble new];
    });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup {

    CGRect frame = CGRectMake(200, 120, 60, 60);

    self.window = [[UIWindow alloc] initWithFrame:frame];
    self.window.windowLevel = UIWindowLevelAlert + 1;
    self.window.backgroundColor = UIColor.clearColor;

    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    self.btn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btn.frame = CGRectMake(0, 0, 60, 60);

    self.btn.backgroundColor = [UIColor colorWithRed:0.1 green:0.6 blue:1 alpha:0.9];
    self.btn.layer.cornerRadius = 30;

    // SAFE ICON (iOS 9+ compatible)
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:24 weight:UIImageSymbolWeightBold];

        UIImage *img =
        [UIImage systemImageNamed:@"arrow.triangle.2.circlepath"
                    withConfiguration:cfg];

        [self.btn setImage:img forState:UIControlStateNormal];
        self.btn.tintColor = UIColor.whiteColor;
    } else {
        [self.btn setTitle:@"↻" forState:UIControlStateNormal];
        self.btn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    }

    [self.btn addTarget:self action:@selector(tap) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    pan.cancelsTouchesInView = NO;

    [self.btn addGestureRecognizer:pan];

    [self.window addSubview:self.btn];
}

- (void)move:(UIPanGestureRecognizer *)g {

    CGPoint t = [g translationInView:self.window];
    self.window.center = CGPointMake(self.window.center.x + t.x,
                                     self.window.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.window];

    if (g.state == UIGestureRecognizerStateBegan)
        self.dragging = YES;

    if (g.state == UIGestureRecognizerStateEnded)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            self.dragging = NO;
        });
}

- (void)tap {
    if (self.dragging) return;

    UIDevice *d = UIDevice.currentDevice;
    ASIdentifierManager *ad = [ASIdentifierManager sharedManager];

    NSString *msg = [NSString stringWithFormat:
                     @"IDFV: %@\nIDFA: %@\nModel: %@\nSystem: %@ %@",
                     d.identifierForVendor.UUIDString,
                     ad.advertisingIdentifier.UUIDString,
                     d.model,
                     d.systemName,
                     d.systemVersion];

    UIAlertController *a =
    [UIAlertController alertControllerWithTitle:@"Device Info"
                                        message:msg
                                 preferredStyle:UIAlertControllerStyleAlert];

    [a addAction:[UIAlertAction actionWithTitle:@"Regenerate"
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction * _Nonnull action) {
        regenerateIDs();
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Close"
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

    [topVC() presentViewController:a animated:YES completion:nil];
}

@end

#pragma mark - Init

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        [SpooferBubble shared];
    });
}
