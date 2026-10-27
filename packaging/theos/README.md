# Theos app package

This scaffold compiles the same sources as `Matinee/Matinee.xcodeproj` into a
Cydia-installable `.deb`. It is an **app**, not a tweak: the result is
`/Applications/Matinee.app`, with its own icon and no MobileSubstrate injection.

It has been built here with Theos and the armv7 slice of the iOS 11.4 SDK,
with a 6.0 deployment target. The resulting binary declares
`LC_VERSION_MIN_IPHONEOS 6.0` and links only iOS 6-era UIKit/Foundation
classes. Device launch is the next test.

## Prerequisites

- [Theos](https://theos.dev) with an SDK that still contains the armv7 slice.
  This scaffold defaults to `$THEOS/sdks/iPhoneOS11.4.sdk`.
- If you have the iOS 6.1 SDK, override the target:
  `make clean package FINALPACKAGE=1 TARGET=iphone:clang:6.1:6.0`.
- `ldid` (Theos ships it).
- A jailbroken iOS 6 device for installation, or `dpkg-deb`/`ar` to inspect the
  package.

```bash
export THEOS=$HOME/theos
git clone --recursive https://github.com/theos/theos.git "$THEOS"
```

## Build

```bash
export THEOS=$HOME/theos
cd packaging/theos
make clean package FINALPACKAGE=1
ls packages/
# com.matinee.app_1.0_iphoneos-arm.deb
```

The default is the 11.4 SDK because it has an armv7 slice and links with
current clang. The build adds `-Wno-error=deprecated-module-dot-map` for the
old SDK's module maps; that warning is harmless.

If the `Matinee` symlink was lost (for example, after downloading a zip on a
system that does not preserve symlinks):

```bash
ln -s ../../Matinee/Matinee Matinee
```

## Inspect and install

```bash
# macOS may not have dpkg-deb; ar + tar works too.
dpkg-deb -I packages/com.matinee.app_1.0_iphoneos-arm.deb
dpkg-deb -c packages/com.matinee.app_1.0_iphoneos-arm.deb | head -30
```

You want to see `Applications/Matinee.app/Matinee`, `Info.plist`, and the icon
files. Install over SSH:

```bash
scp packages/com.matinee.app_1.0_iphoneos-arm.deb root@DEVICE_IP:/tmp/
ssh root@DEVICE_IP \
  'dpkg -i /tmp/com.matinee.app_1.0_iphoneos-arm.deb && killall -9 SpringBoard'
```

Or host the `.deb` in a Cydia repo; see `../../docs/GUIDE.md` section 5.

## Configuration

The app's default relay is the placeholder in `MTStore.m`. Change it before
building, or launch the app and use **Profile → Change server**. The device and
the relay machine must be on the same network.

## What this scaffold deliberately does not do

- It does not inject into Letterboxd. That is a tweak, with a different
  `Makefile`, a `Filter` plist, and a `mobilesubstrate` dependency. See
  `../../docs/GUIDE.md` section 4.
- It does not bundle an SDK. Apple's SDK licensing is your responsibility.
- It does not sign with a developer certificate. Theos uses `ldid -S` for a
  jailbroken device.

## If the build fails

| Error | Likely cause |
| --- | --- |
| `Unable to locate SDK` | `iPhoneOS11.4.sdk` is not in `$THEOS/sdks`; set `MATINEE_SDK` or override `TARGET` |
| `UIKit/UIKit.h not found` | Wrong `TARGET` or missing SDK |
| `module.map ... deprecated` | Already downgraded with `-Wno-error=deprecated-module-dot-map`; if your clang rejects the flag, remove it |
| `libobjc.A.tbd ... built for 'iOS-simulator'` | The 9.3 SDK's stub is mixed; use the 11.4 SDK (default) or a device-only 6.1 SDK |
| `library for install name '/usr/lib/system/liblaunch.dylib' not found` | Older SDK stub warning; the 11.4 build links cleanly |
| `Matinee/*.m: No such file` | The `Matinee` symlink is missing |
| App installs but crashes | Check `ldid -S`, the 6.0 deployment target, and the relay URL |
