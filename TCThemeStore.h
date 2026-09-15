#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个主题包（/Library/Themes/*.theme）的模型
@interface TCTheme : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *packageName;  // Info.plist: PackageName
@property (nonatomic, assign) BOOL modern;                    // 是否使用 modern 资源
@property (nonatomic, assign) NSUInteger iconCount;
@property (nonatomic, assign) NSUInteger extensionCount;
@property (nonatomic, assign) BOOL hasClock;
@property (nonatomic, assign) BOOL hasShadow;
- (instancetype)initWithPath:(NSString *)path;
@end

/// 主题全局存储：扫描 /Library/Themes，合并启用的主题，
/// 在 /Library/ThemeCore 下生成编译后的资源并做缓存。
@interface TCThemeStore : NSObject

@property (class, readonly, strong) TCThemeStore *sharedStore;

/// 插件总开关（对应偏好 Enabled）
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
/// 当前激活主题名（对应偏好 ActiveTheme）
@property (nonatomic, copy, nullable) NSString *activeTheme;
/// 已启用主题集合（对应偏好 EnabledThemes）
@property (nonatomic, copy) NSArray<NSString *> *enabledThemes;
/// 全部可用主题（按名称排序）
@property (nonatomic, readonly, copy) NSArray<TCTheme *> *themes;

/// 主题信息字典（identifier -> 资源路径），供 hooks 查询
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *iconPaths;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *clockPaths;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *resolvedShadowPaths;

/// 主题 Info.plist 合并后的元信息（如 CalendarIconDateSettings / DaySettings）
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *themeInfo;

/// 资源代次：每次 reload 自增，缓存键随之失效
@property (nonatomic, readonly) NSUInteger generation;

/// 重新扫描并合并主题；由偏好变更或 darwin 通知触发
- (void)reload;

/// 取某个 bundle 的主题图标（scale 对应设备屏幕 scale）
- (nullable UIImage *)imageForBundleIdentifier:(NSString *)bundleIdentifier scale:(CGFloat)scale;

/// 取时钟资源（表盘背景/指针/圆点）
- (nullable UIImage *)clockResourceForKey:(NSString *)key scale:(CGFloat)scale;

/// 取图标阴影蒙版图
- (nullable UIImage *)shadowImageForScale:(CGFloat)scale;

/// 是否有生效阴影
- (BOOL)hasShadow;

/// 是否使用 modern 资源格式
- (BOOL)isModern;

/// 内存压力时清空缓存
- (void)evictCaches;

@end

NS_ASSUME_NONNULL_END
