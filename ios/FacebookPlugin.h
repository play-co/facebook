#import "PluginManager.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>

@interface FacebookPlugin : GCPlugin {
    bool frictionlessRequestsEnabled;
}

@property (assign) NSNumber * loginRequestId;
@property (assign) TeaLeafViewController *tealeafViewController;

@end

