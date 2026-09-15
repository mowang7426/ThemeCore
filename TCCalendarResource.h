#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 动态日历图标：使用主题日历素材，叠加当前日期数字
@interface TCCalendarResource : NSObject

+ (nullable instancetype)currentResource;

/// 渲染带当前日期的日历图标
- (nullable UIImage *)imageForDate:(NSDate *)date scale:(CGFloat)scale;

@end

NS_ASSUME_NONNULL_END
