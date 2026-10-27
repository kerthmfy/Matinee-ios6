# Theos application scaffold for Matinee.
#
# The Matinee/ symlink points at ../../Matinee/Matinee so this project compiles
# the same sources as the Xcode target. If the symlink is missing:
#
#   ln -s ../../Matinee/Matinee Matinee
#
# Build:
#
#   export THEOS=$HOME/theos
#   make clean package FINALPACKAGE=1
#
# This defaults to the 11.4 SDK because it still ships an armv7 slice and
# links with current clang. The deployment target stays 6.0, so the app still
# runs on iOS 6. If you have the 6.1 SDK, override it:
#
#   make clean package FINALPACKAGE=1 TARGET=iphone:clang:6.1:6.0
#
# See README.md for the SDK and linker caveats.

MATINEE_SDK ?= 11.4
TARGET := iphone:clang:$(MATINEE_SDK):6.0
ARCHS := armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Matinee

Matinee_FILES = $(wildcard Matinee/*.m)
Matinee_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore MessageUI
Matinee_CFLAGS = -fobjc-arc -mno-thumb -Wno-error=deprecated-module-dot-map
Matinee_CODESIGN_FLAGS = -S
Matinee_INSTALL_PATH = /Applications

# Keep Info.plist and the icon files at the app bundle root.
Matinee_RESOURCE_FILES = \
	Matinee/Info.plist \
	Matinee/Resources/Icon.png \
	Matinee/Resources/Icon@2x.png \
	Matinee/Resources/Icon-72.png \
	Matinee/Resources/Icon-72@2x.png \
	Matinee/Resources/iTunesArtwork.png

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 Matinee || true"
