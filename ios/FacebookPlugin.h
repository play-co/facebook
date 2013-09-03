#import "PluginManager.h"
#import <FacebookSDK/FacebookSDK.h>

@interface FacebookPlugin : GCPlugin

@property (retain, nonatomic) UINavigationController *navController;

@property bool bHaveRequestedPublishPermissions;

- (void) sessionStateChanged:(FBSession *)session
					   state:(FBSessionState) state
					   error:(NSError *)error;

- (void) openSession:(BOOL)allowLoginUI;

@end
