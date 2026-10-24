THEOS_DEVICE_IP = 192.168.100.X
TARGET := iphone:clang:latest:6.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Matinee-ios6

Matinee-ios6_FILES = \
    main.m \
    MTAppDelegate.m \
    MTStore.m \
    MTDraft.m \
    MTEntry.m \
    MTSecureClient.m \
    MTDebugViewController.m \
    MTSearchViewController.m \
    MTProfileViewController.m \
    MTFilmViewController.m \
    MTDiaryViewController.m \
    MTListsViewController.m \
    MTLogViewController.m \
    MTAppearance.m \
    MTFeedModels.m \
    MTFeedService.m \
    MTImageCache.m \
    MTMarkView.m \
    MTPosterStripView.m \
    MTStarsView.m \
    MTHomeTheme.m \
    MTFilm.m \
    MTHomeViewController.m

Matinee-ios6_FRAMEWORKS = UIKit Foundation QuartzCore
Matinee-ios6_LIBRARIES = mbedtls mbedcrypto mbedx509

# Point to your local static libraries and headers
Matinee-ios6_LDFLAGS = -L./mbedtls/library
Matinee-ios6_CFLAGS = -I./mbedtls/include -Wno-deprecated-declarations -Wno-unused-variable

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "uicache; killall -9 SpringBoard"