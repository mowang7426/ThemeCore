#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

/// 图标阴影层：在图标下方渲染主题阴影蒙版
/// 兼容 AnemoneEffects / Effects/Shadow 资源，modern 模式用真实投影
@interface TCShadowLayer : CALayer

/// 安装阴影到某个图标视图（返回是否成功）
+ (BOOL)installShadowOnView:(UIView *)iconView;

/// 使全部已安装阴影失效（主题切换后调用）
+ (void)invalidateAll;

@end

NS_ASSUME_NONNULL_END
