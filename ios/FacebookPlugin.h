#import "PluginManager.h"
#import <FacebookSDK/FacebookSDK.h>

@interface FacebookPlugin : GCPlugin

@property (retain, nonatomic) UINavigationController *navController;
@property (retain, nonatomic) FBFrictionlessRecipientCache* ms_friendCache;

- (void) sessionStateChanged:(FBSession *)session
					   state:(FBSessionState) state
					   error:(NSError *)error;

- (void) openSession:(BOOL)allowLoginUI;

@end
