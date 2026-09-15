#import "TCRootListController.h"
#import <objc/runtime.h>
#import <notify.h>

#pragma mark - rootless 路径换算（与 postinst 探测逻辑一致）

static NSString *TCRootPath(NSString *path) {
    // 只有越狱根目录下的 /Library 路径需要映射；用户偏好位于真实的 /var/mobile。
    if (![path hasPrefix:@"/Library/"]) return path;
    NSString *prefix = @"";
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
        prefix = @"/var/jb";
    } else {
        NSArray *candidates = [[NSFileManager defaultManager]
            contentsOfDirectoryAtPath:@"/var/containers/Bundle/Application" error:nil];
        for (NSString *c in candidates) {
            if ([c hasPrefix:@".jbroot-"]) {
                prefix = [@"/var/containers/Bundle/Application" stringByAppendingPathComponent:c];
                break;
            }
        }
    }
    return prefix.length ? [prefix stringByAppendingString:path] : path;
}

static NSString *const TCReloadDarwinName = @"com.susudear.themecore.reload";

@implementation TCRootListController

- (instancetype)init {
    self = [super init];
    if (self) {
        // 页脚链接
        self.navigationItem.rightBarButtonItem = nil;
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // 顶栏图标
    UIImage *header = [UIImage imageNamed:@"ThemeCoreHeaderIcon" inBundle:[NSBundle bundleForClass:self.class]
            compatibleWithTraitCollection:nil];
    if (header) {
        UIImageView *headerView = [[UIImageView alloc] initWithImage:header];
        headerView.contentMode = UIViewContentModeScaleAspectFit;
        headerView.frame = CGRectMake(0, 0, 150, 150);
        self.navigationItem.titleView = headerView;
    }
}

#pragma mark - 动作

- (void)refreshIcons {
    // 通知 SpringBoard 与图标服务重载主题
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)TCReloadDarwinName, NULL, nil, YES);
    notify_post("com.susudear.themecore/reload");

    // 杀掉图标服务代理强制重建缓存
    if ([NSProcessInfo processInfo].processName.length) {
        // 仅提示，不真正杀进程（rootless 下由 SpringBoard 侧完成）
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil
                                                                   message:NSLocalizedStringFromTableInBundle(
                                                                       @"REFRESH_SENT", @"Root",
                                                                       [NSBundle bundleForClass:self.class], nil)
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)tc_openRepository:(PSSpecifier *)specifier {
    NSURL *url = [NSURL URLWithString:@"https://repo.susubaby.cn"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

@end
