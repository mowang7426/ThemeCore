#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 单个主题项（模型）
@interface TCThemeItem : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *packageName;
@property (nonatomic, assign) NSUInteger iconCount;
@property (nonatomic, assign) NSUInteger extensionCount;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong, nullable) UIImage *previewImage;
@end

/// 主题列表分组
@interface TCThemeGroup : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<TCThemeItem *> *items;
@end

/// 预览 cell：显示主题缩略图与统计信息
@interface ThemeCoreThemePreviewCell : UITableViewCell
@property (nonatomic, strong) TCThemeItem *item;
@property (nonatomic, copy, nullable) void (^onToggle)(TCThemeItem *item);
@end

NS_ASSUME_NONNULL_END
