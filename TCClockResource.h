#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 动态时钟图标：根据主题素材（表盘/时针/分针/秒针/圆点）绘制当前时间
@interface TCClockResource : NSObject

@property (nonatomic, readonly) BOOL modern;
@property (nonatomic, readonly) BOOL hasBackground;

/// 从主题 store 构建时钟资源
+ (nullable instancetype)currentResource;

/// 渲染指定时刻的时钟图标
- (nullable UIImage *)imageForDate:(NSDate *)date scale:(CGFloat)scale;

@end

NS_ASSUME_NONNULL_END
