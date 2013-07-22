#import "PluginManager.h"
#import <FacebookSDK/FacebookSDK.h>

@interface FacebookPlugin : GCPlugin

@property (retain, nonatomic) UINavigationController *navController;

- (void) sessionStateChanged:(FBSession *)session
					   state:(FBSessionState) state
					   error:(NSError *)error;

- (void) openSession:(BOOL)allowLoginUI;

@end
