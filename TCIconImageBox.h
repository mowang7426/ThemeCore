#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 图标图像盒：把主题 PNG 解码为 CGImage，供 IconServices / SpringBoard 图标管线使用。
/// 负责 scale 适配、占位图回退、内存缓存。
@interface TCIconImageBox : NSObject

@property (nonatomic, readonly, nullable) CGImageRef image;
@property (nonatomic, readonly) CGSize pixelSize;
@property (nonatomic, readonly) BOOL placeholder;

+ (nullable instancetype)imageBoxForBundleIdentifier:(NSString *)bundleIdentifier
                                               scale:(CGFloat)scale
                                         minimumSize:(CGSize)minimumSize;

+ (nullable instancetype)imageBoxWithCGImage:(CGImageRef)cgImage
                                       scale:(CGFloat)scale
                                 minimumSize:(CGSize)minimumSize
                                 placeholder:(BOOL)placeholder;

- (void)clearCache;

@end

NS_ASSUME_NONNULL_END
