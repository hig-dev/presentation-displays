#import "PresentationDisplaysPlugin.h"
#if __has_include(<presentation_displays_hig/presentation_displays_hig-Swift.h>)
#import <presentation_displays_hig/presentation_displays_hig-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "presentation_displays_hig-Swift.h"
#endif

@implementation PresentationDisplaysPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPresentationDisplaysPlugin registerWithRegistrar:registrar];
}
@end
