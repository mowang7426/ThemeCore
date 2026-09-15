#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

/// ThemeCore 设置根面板
@interface TCRootListController : PSListController

/// “刷新图标”按钮动作：发布 darwin 通知并杀掉图标服务
- (void)refreshIcons;
/// 页脚打开越狱源
- (void)tc_openRepository:(PSSpecifier *)specifier;

@end

NS_ASSUME_NONNULL_END
