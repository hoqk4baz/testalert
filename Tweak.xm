#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

static UITextView *logView;

#define ADD_LOG(fmt, ...) [Logger add:[NSString stringWithFormat:fmt, ##__VA_ARGS__]]

@interface Logger : NSObject
+ (void)add:(NSString *)text;
@end

@implementation Logger

+ (void)setupIfNeeded {
    if (logView) return;

    UIWindow *window = UIApplication.sharedApplication.windows.firstObject;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 80, 320, 300)];
    panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    panel.layer.cornerRadius = 12;

    logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, 300, 280)];
    logView.backgroundColor = UIColor.clearColor;
    logView.textColor = UIColor.greenColor;
    logView.editable = NO;
    logView.font = [UIFont systemFontOfSize:12];

    [panel addSubview:logView];
    [window addSubview:panel];
}

+ (void)add:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setupIfNeeded];

        NSString *old = logView.text ?: @"";
        NSString *newText = [old stringByAppendingFormat:@"\n%@", text];

        logView.text = newText;

        // auto scroll
        NSRange bottom = NSMakeRange(newText.length, 1);
        [logView scrollRangeToVisible:bottom];
    });
}

@end

#pragma mark - HOOKS

%hook UIDevice

- (NSUUID *)identifierForVendor {
    NSUUID *u = %orig;
    ADD_LOG(@"UIDevice IDFV -> %@", u.UUIDString);
    return u;
}

%end

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    NSUUID *u = %orig;
    ADD_LOG(@"IDFA -> %@", u.UUIDString);
    return u;
}

%end

%hook NSUUID

- (NSString *)UUIDString {
    NSString *s = %orig;
    ADD_LOG(@"NSUUID -> %@", s);
    return s;
}

%end
