//
//  main.m
//  Matinee
//

#import <UIKit/UIKit.h>
#import "MTAppDelegate.h"

// Theos links this binary without crt1.o, so LC_MAIN points straight at main.
// iOS 6's dyld jumps there without setting the Thumb bit, which makes a Thumb
// main run as ARM and die with SIGILL before any code executes. Build just
// this function as ARM so the entry point is valid; everything else stays
// Thumb.
__attribute__((target("arm")))
int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([MTAppDelegate class]));
    }
}
