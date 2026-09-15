// ThemeCore.xm — 主 Tweak 入口
//
// 独立重写实现（基于公开行为观察，非原二进制反编译）。
// 加载进程：SpringBoard / iconservicesagent / ShareUI / sharingd（见 ThemeCore.plist）
//
// 覆盖范围：
//   - 主屏图标（SBHIconImageCache / SBIconView / SBApplicationIcon）
//   - 文件夹图标、App 资源库图标、Widget 图标
//   - 动态时钟 / 日历图标
//   - 通知中心图标（NCNotificationRequest）
//   - 分享面板 AirDrop 图标（sharingd / ShareUI）
//   - iconservicesagent 图标服务（ISGenerationRequest / IFCacheImage）
//   - 图标阴影（Effects/Shadow 蒙版）

#import "TCThemeStore.h"
#import "TCClockResource.h"
#import "TCCalendarResource.h"
#import "TCShadowLayer.h"
#import "TCIconImageBox.h"
#import <substrate.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - 私有类接口桩
// Logos 只会为 %hook 的类生成 @class 前向声明，编译器不知道父类，
// 直接在 hook 内给 self 发消息（respondsToSelector: / .image / 传 UIView* 参数）会报
// “receiver type is a forward declaration”。这里声明最小接口桩（只给父类与用到的成员）。

@interface SBHIconImageCache : NSObject @end
@interface SBApplicationIcon : NSObject @end
@interface SBIconView : UIView @end
@interface SBFolderIconView : UIView @end
@interface SBHClockApplicationIconImageView : UIImageView @end
@interface SBClockApplicationIconImageView : UIImageView @end
@interface SBHCalendarApplicationIcon : NSObject @end
@interface SBCalendarApplicationIcon : NSObject @end
@interface SBHLibraryPodCategoryIcon : NSObject @end
@interface NCNotificationRequest : NSObject @end
@interface SBHIconTableViewCell : UITableViewCell @end
@interface LSApplicationProxy : NSObject @end
@interface UIAirDropActivity : UIActivity @end
@interface WGWidgetHostingViewController : UIViewController @end
@interface ISGenerationRequest : NSObject @end
@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
@end

// id / Class 上调用的私有选择器统一在 NSObject 分类里声明，避免
// “no known instance/class method for selector” 编译错误（运行时解析）。
@interface NSObject (TCPrivateSelectors)
+ (instancetype)sharedInstance;
- (void)reloadIconImage;
- (void)enumerateDisplayedIconViewsUsingBlock:(void (^)(id iconView))block;
- (instancetype)initWithCGImage:(CGImageRef)cgImage
                          scale:(CGFloat)scale
                    minimumSize:(CGSize)minimumSize
                    placeholder:(BOOL)placeholder;
@end

static NSString *const kTCReloadDarwinName = @"com.susudear.themecore.reload";

static void TCThemeReloadCallback(CFNotificationCenterRef center, void *observer,
                                  CFStringRef name, const void *object, CFDictionaryRef userInfo);

#pragma mark - 工具函数

/// 从任意 icon 对象安全取出 bundle id
static NSString *TCBundleIDForIcon(id icon) {
    if (!icon) return nil;
    // SBApplicationIcon / SBLeafIcon / ISBundleIdentifierIcon 等
    SEL sel = NSSelectorFromString(@"applicationBundleID");
    if ([icon respondsToSelector:sel]) {
        NSString *bid = ((NSString *(*)(id, SEL))objc_msgSend)(icon, sel);
        if (bid.length) return bid;
    }
    sel = NSSelectorFromString(@"bundleIdentifier");
    if ([icon respondsToSelector:sel]) {
        NSString *bid = ((NSString *(*)(id, SEL))objc_msgSend)(icon, sel);
        if (bid.length) return bid;
    }
    return nil;
}

/// 查主题图标
static UIImage *TCThemedImage(id icon, CGFloat scale) {
    TCThemeStore *store = TCThemeStore.sharedStore;
    if (!store.enabled) return nil;
    NSString *bid = TCBundleIDForIcon(icon);
    if (!bid.length) return nil;
    if ([bid isEqualToString:@"com.apple.mobilecal"]) {
        return [[TCCalendarResource currentResource] imageForDate:[NSDate date] scale:scale];
    }
    return [store imageForBundleIdentifier:bid scale:scale];
}

#pragma mark - SpringBoard：图标图片缓存

// SBHIconImageCache —— 主屏图标缓存，主题图优先
%hook SBHIconImageCache

- (UIImage *)cachedImageForIcon:(id)icon {
    UIImage *themed = TCThemedImage(icon, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

- (UIImage *)imageForIcon:(id)icon {
    UIImage *themed = TCThemedImage(icon, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

- (UIImage *)realImageForIcon:(id)icon {
    UIImage *themed = TCThemedImage(icon, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

%end

#pragma mark - SpringBoard：应用图标生成

%hook SBApplicationIcon

- (id)genericIconImageWithInfo:(id)info {
    UIImage *themed = TCThemedImage(self, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

- (id)unmaskedIconImageWithInfo:(id)info {
    UIImage *themed = TCThemedImage(self, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

- (id)iconImageWithInfo:(id)info {
    UIImage *themed = TCThemedImage(self, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

- (id)generateIconImageWithInfo:(id)info {
    UIImage *themed = TCThemedImage(self, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

- (id)getUnmaskedIconImage:(id)arg {
    UIImage *themed = TCThemedImage(self, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

- (id)generateIconImage:(id)arg {
    UIImage *themed = TCThemedImage(self, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}

%end

#pragma mark - SpringBoard：图标视图与阴影

%hook SBIconView

- (void)layoutSubviews {
    %orig;
    if (TCThemeStore.sharedStore.hasShadow && [self respondsToSelector:NSSelectorFromString(@"icon")]) {
        id icon = [self valueForKey:@"icon"];
        if (TCBundleIDForIcon(icon)) {
            [TCShadowLayer installShadowOnView:self];
        }
    }
}

- (void)reloadIconImage {
    // 主题刷新后由刷新流程调用
    %orig;
}

%end

%hook SBFolderIconView

- (void)layoutSubviews {
    %orig;
    if (TCThemeStore.sharedStore.hasShadow) {
        [TCShadowLayer installShadowOnView:self];
    }
}

%end

#pragma mark - 动态时钟图标

%hook SBHClockApplicationIconImageView

- (void)updateClockImages {
    %orig;
    TCClockResource *res = [TCClockResource currentResource];
    if (res) {
        UIImage *img = [res imageForDate:[NSDate date] scale:UIScreen.mainScreen.scale];
        if (img) self.image = img;
    }
}

- (void)updateImageAnimated:(BOOL)animated {
    %orig;
    TCClockResource *res = [TCClockResource currentResource];
    if (res) {
        UIImage *img = [res imageForDate:[NSDate date] scale:UIScreen.mainScreen.scale];
        if (img) self.image = img;
    }
}

%end

%hook SBClockApplicationIconImageView

- (void)updateClockImages {
    %orig;
    TCClockResource *res = [TCClockResource currentResource];
    if (res) {
        UIImage *img = [res imageForDate:[NSDate date] scale:UIScreen.mainScreen.scale];
        if (img) self.image = img;
    }
}

%end

#pragma mark - 动态日历图标

%hook SBHCalendarApplicationIcon
- (id)generateIconImageWithInfo:(id)info {
    TCCalendarResource *res = [TCCalendarResource currentResource];
    if (res) {
        UIImage *img = [res imageForDate:[NSDate date] scale:UIScreen.mainScreen.scale];
        if (img) return img;
    }
    return %orig;
}
%end

%hook SBCalendarApplicationIcon
- (id)generateIconImageWithInfo:(id)info {
    TCCalendarResource *res = [TCCalendarResource currentResource];
    if (res) {
        UIImage *img = [res imageForDate:[NSDate date] scale:UIScreen.mainScreen.scale];
        if (img) return img;
    }
    return %orig;
}
%end

#pragma mark - 通知中心图标

%hook NCNotificationRequest

- (id)_compositedIconImageForFormat:(long long)format withBaseImageProvider:(id)provider {
    // 通知横幅/列表中的应用图标
    id content = [self valueForKey:@"content"];
    id icon = content ? [content valueForKey:@"icon"] : nil;
    if ([icon isKindOfClass:NSClassFromString(@"SBApplicationIcon")] ||
        [icon isKindOfClass:NSClassFromString(@"SBIcon")]) {
        UIImage *themed = TCThemedImage(icon, UIScreen.mainScreen.scale);
        if (themed) return themed;
    }
    return %orig;
}

%end

#pragma mark - App 资源库 / 文件夹内图标

%hook SBHIconTableViewCell

- (void)layoutSubviews {
    %orig;
    if (TCThemeStore.sharedStore.hasShadow) {
        [TCShadowLayer installShadowOnView:self];
    }
}

%end

%hook SBHLibraryPodCategoryIcon
- (id)generateIconImage:(id)arg {
    UIImage *themed = TCThemedImage(self, UIScreen.mainScreen.scale);
    if (themed) return themed;
    return %orig;
}
%end

#pragma mark - 分享面板（sharingd / ShareUI）

%hook LSApplicationProxy

- (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(NSInteger)format scale:(CGFloat)scale {
    UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:bundleID scale:scale];
    if (themed) return themed;
    return %orig;
}

- (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(NSInteger)format {
    UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:bundleID scale:UIScreen.mainScreen.scale];
    if (themed) return themed;
    return %orig;
}

- (UIImage *)iconForBundleIdentifier:(NSString *)bundleID {
    UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:bundleID scale:UIScreen.mainScreen.scale];
    if (themed) return themed;
    return %orig;
}

%end

%hook UIAirDropActivity

- (UIImage *)_activityImage {
    UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:@"com.apple.AirDrop"
                                                                   scale:UIScreen.mainScreen.scale];
    if (themed) return themed;
    return %orig;
}

- (UIImage *)_activitySettingsImage {
    UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:@"com.apple.AirDrop"
                                                                   scale:UIScreen.mainScreen.scale];
    if (themed) return themed;
    return %orig;
}

%end

#pragma mark - Widget 图标

%hook WGWidgetHostingViewController

- (void)requestIconWithHandler:(id)handler {
    NSString *bid = [self respondsToSelector:NSSelectorFromString(@"widgetIdentifier")]
        ? [self valueForKey:@"widgetIdentifier"] : nil;
    if (bid) {
        UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:bid scale:UIScreen.mainScreen.scale];
        if (themed) {
            void (^block)(UIImage *) = handler;
            block(themed);
            return;
        }
    }
    %orig;
}

- (void)requestSettingsIconWithHandler:(id)handler {
    NSString *bid = [self respondsToSelector:NSSelectorFromString(@"widgetIdentifier")]
        ? [self valueForKey:@"widgetIdentifier"] : nil;
    if (bid) {
        UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:bid scale:UIScreen.mainScreen.scale];
        if (themed) {
            void (^block)(UIImage *) = handler;
            block(themed);
            return;
        }
    }
    %orig;
}

%end

#pragma mark - iconservicesagent：图标服务

%hook ISGenerationRequest

- (id)generateImageReturningRecordIdentifiers:(id)arg1 {
    id icon = [self respondsToSelector:NSSelectorFromString(@"icon")] ? [self valueForKey:@"icon"] : nil;
    NSString *bid = TCBundleIDForIcon(icon);
    if (bid.length) {
        CGFloat scale = UIScreen.mainScreen.scale;
        UIImage *themed = [TCThemeStore.sharedStore imageForBundleIdentifier:bid scale:scale];
        if (themed) {
            Class boxClass = NSClassFromString(@"IFCacheImage");
            if (boxClass) {
                id record = [[boxClass alloc] initWithCGImage:themed.CGImage
                                                        scale:scale
                                                  minimumSize:CGSizeZero
                                                  placeholder:NO];
                if (record) return @[record];
            }
        }
    }
    return %orig;
}

%end

#pragma mark - 刷新流程

%hook SBIconController

- (void)reloadIcons {
    %orig;
    [TCThemeStore.sharedStore reload];
}

%end

#pragma mark - 构造函数

%ctor {
    // 监听主题变更 darwin 通知 → 刷新图标与阴影
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        TCThemeReloadCallback,
        (__bridge CFStringRef)kTCReloadDarwinName,
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
}

static void TCThemeReloadCallback(CFNotificationCenterRef center, void *observer,
                                  CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // 重新读取偏好并合并主题（reload 内部会读 Enabled 开关）
    [TCThemeStore.sharedStore reload];
    [TCShadowLayer invalidateAll];

    dispatch_async(dispatch_get_main_queue(), ^{
        Class ctrlClass = NSClassFromString(@"SBIconController");
        if (!ctrlClass) return;
        id controller = [ctrlClass respondsToSelector:@selector(sharedInstance)]
            ? [ctrlClass sharedInstance] : nil;
        if (!controller) return;

        // 刷新主屏显示中的图标
        id rootFolder = [controller respondsToSelector:NSSelectorFromString(@"_rootFolderController")]
            ? [controller valueForKey:@"_rootFolderController"] : nil;
        if ([rootFolder respondsToSelector:NSSelectorFromString(@"enumerateDisplayedIconViewsUsingBlock:")]) {
            [rootFolder enumerateDisplayedIconViewsUsingBlock:^(id iconView) {
                if ([iconView respondsToSelector:NSSelectorFromString(@"reloadIconImage")]) {
                    [iconView reloadIconImage];
                }
                if ([iconView isKindOfClass:NSClassFromString(@"SBIconView")]) {
                    [TCShadowLayer installShadowOnView:iconView];
                }
            }];
        }
    });
}
