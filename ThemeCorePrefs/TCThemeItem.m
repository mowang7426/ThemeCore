#import "TCThemeItem.h"
#import <Preferences/PSSpecifier.h>

@implementation TCThemeItem
@end

@implementation TCThemeGroup
@end

@implementation ThemeCoreThemePreviewCell {
    UIImageView *_previewView;
    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UISwitch *_switch;
    UIButton *_toggleButton;
    NSLayoutConstraint *_subtitleTrailingToButtonConstraint;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _previewView = [UIImageView new];
        _previewView.contentMode = UIViewContentModeScaleAspectFit;
        _previewView.layer.cornerRadius = 10;
        _previewView.clipsToBounds = YES;
        _previewView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_previewView];

        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_titleLabel];

        _subtitleLabel = [UILabel new];
        _subtitleLabel.font = [UIFont systemFontOfSize:12];
        _subtitleLabel.textColor = [UIColor secondaryLabelColor];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_subtitleLabel];

        _toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _toggleButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_toggleButton setTitle:@"启用" forState:UIControlStateNormal];
        [_toggleButton setTitle:@"禁用" forState:UIControlStateSelected];
        [_toggleButton addTarget:self action:@selector(_toggleTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_toggleButton];

        [NSLayoutConstraint activateConstraints:@[
            [_previewView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
            [_previewView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_previewView.widthAnchor constraintEqualToConstant:52],
            [_previewView.heightAnchor constraintEqualToConstant:52],

            [_titleLabel.leadingAnchor constraintEqualToAnchor:_previewView.trailingAnchor constant:12],
            [_titleLabel.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_toggleButton.leadingAnchor constant:-8],

            [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
            [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],

            [_toggleButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
            [_toggleButton.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [_toggleButton.widthAnchor constraintGreaterThanOrEqualToConstant:60],
        ]];
    }
    return self;
}

- (void)setItem:(TCThemeItem *)item {
    _item = item;
    _previewView.image = item.previewImage ?: [UIImage imageNamed:@"ThemePlaceholder"
                                                        inBundle:[NSBundle bundleForClass:self.class]
                                   compatibleWithTraitCollection:nil];
    _titleLabel.text = item.packageName.length ? item.packageName : item.name;
    if (item.extensionCount > 0) {
        _subtitleLabel.text = [NSString stringWithFormat:@"%lu 个图标, %lu 个扩展",
                               (unsigned long)item.iconCount, (unsigned long)item.extensionCount];
    } else {
        _subtitleLabel.text = [NSString stringWithFormat:@"%lu 个图标", (unsigned long)item.iconCount];
    }
    _toggleButton.selected = item.enabled;
    _toggleButton.hidden = item.isActive;   // 激活中的主题直接显示
}

- (void)_toggleTapped {
    if (self.onToggle) self.onToggle(self.item);
}

@end
