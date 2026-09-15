#import "TCShadowLayer.h"
#import "TCThemeStore.h"

/// 弱引用表：跟踪所有已安装的阴影层
@interface TCShadowLayer ()
@property (nonatomic, weak) UIView *hostView;
@end

@implementation TCShadowLayer {
    NSUUID *_token;
}

static NSHashTable<TCShadowLayer *> *gInstalledLayers;

+ (void)initialize {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gInstalledLayers = [NSHashTable weakObjectsHashTable];
    });
}

+ (BOOL)installShadowOnView:(UIView *)iconView {
    TCThemeStore *store = TCThemeStore.sharedStore;
    if (!store.hasShadow || !iconView) return NO;

    // 已经装过就不再重复安装
    for (TCShadowLayer *layer in gInstalledLayers) {
        if (layer.hostView == iconView) return YES;
    }

    UIImage *shadowImage = [store shadowImageForScale:UIScreen.mainScreen.scale];
    if (!shadowImage) return NO;

    TCShadowLayer *shadow = [TCShadowLayer layer];
    shadow.hostView = iconView;
    shadow.contents = (__bridge id)shadowImage.CGImage;
    shadow.contentsScale = UIScreen.mainScreen.scale;
    shadow.contentsGravity = kCAGravityResizeAspect;
    shadow.opacity = 0.9f;
    shadow.zPosition = -1;   // 置于图标之下
    shadow.name = @"ThemeCoreIconShadow";

    // 用图标图像形状做蒙版，使阴影贴合图标轮廓
    if (iconView.layer.contents) {
        CALayer *mask = [CALayer layer];
        mask.contents = iconView.layer.contents;
        mask.contentsScale = iconView.layer.contentsScale;
        mask.contentsGravity = kCAGravityResizeAspect;
        mask.frame = iconView.layer.bounds;
        shadow.mask = mask;
    }

    [iconView.layer addSublayer:shadow];
    [gInstalledLayers addObject:shadow];
    return YES;
}

+ (void)invalidateAll {
    for (TCShadowLayer *layer in gInstalledLayers) {
        [layer removeFromSuperlayer];
    }
    [gInstalledLayers removeAllObjects];
}

- (void)layoutSublayers {
    [super layoutSublayers];
    UIView *host = self.hostView;
    if (host) {
        self.frame = host.bounds;
        self.mask.frame = host.bounds;
    }
}

@end
