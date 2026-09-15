TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ThemeCore

ThemeCore_FILES = ThemeCore.xm \
	TCThemeStore.m \
	TCClockResource.m \
	TCCalendarResource.m \
	TCShadowLayer.m \
	TCIconImageBox.m

ThemeCore_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ThemeCore_FRAMEWORKS = UIKit Foundation CoreGraphics CoreFoundation QuartzCore ImageIO
ThemeCore_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = ThemeCorePrefs

ThemeCorePrefs_FILES = ThemeCorePrefs/TCRootListController.m \
	ThemeCorePrefs/TCThemeListController.m \
	ThemeCorePrefs/TCThemeItem.m

ThemeCorePrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ThemeCorePrefs_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
# iPhoneOS16.5 SDK 不含私有框架 Preferences 的 .tbd（ld: framework 'Preferences' not found）。
# 设置 bundle 由 Preferences 进程加载，PSListController/PSSpecifier 运行时已在进程内，
# 头文件用 theos 精简头编译，符号改为运行时动态查找即可，无需链接该框架。
ThemeCorePrefs_LDFLAGS = -undefined dynamic_lookup
ThemeCorePrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard" || true
