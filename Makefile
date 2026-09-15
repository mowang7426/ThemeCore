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
ThemeCorePrefs_PRIVATE_FRAMEWORKS = Preferences
ThemeCorePrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard" || true
