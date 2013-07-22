#import "FacebookPlugin.h"

@implementation FacebookPlugin

// The plugin must call super dealloc.
- (void) dealloc {
	[super dealloc];
}

// The plugin must call super init.
- (id) init {
	self = [super init];
	if (!self) {
		return nil;
	}

	return self;
}

- (void) sessionStateChanged:(FBSession *)session
					   state:(FBSessionState) state
					   error:(NSError *)error {

	// If state indicates the session is open,
	if (FB_ISSESSIONOPENWITHSTATE(state)) {
		// Notify JS
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"facebookState",@"name",
											  @"open",@"state",
											  nil]];
	} else if (FB_ISSESSIONSTATETERMINAL(state)) {
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"facebookState",@"name",
											  @"closed",@"state",
											  nil]];
		
		[FBSession.activeSession closeAndClearTokenInformation];
		[FBSession setActiveSession:nil];
	}

	// Print the state to console
    switch (state) {
		case FBSessionStateOpenTokenExtended:
			NSLog(@"{facebook} Session state: FBSessionStateOpenTokenExtended");
			break;
        case FBSessionStateOpen:
			NSLog(@"{facebook} Session state: FBSessionStateOpen");
			break;
        case FBSessionStateClosed:
			NSLog(@"{facebook} Session state: FBSessionStateClosed");
			break;
        case FBSessionStateClosedLoginFailed:
			NSLog(@"{facebook} Session state: FBSessionStateClosedLoginFailed");
            break;
		case FBSessionStateCreated:
			NSLog(@"{facebook} Session state: FBSessionStateCreated");
            break;
		case FBSessionStateCreatedTokenLoaded:
			NSLog(@"{facebook} Session state: FBSessionStateCreatedTokenLoaded");
            break;
		case FBSessionStateCreatedOpening:
			NSLog(@"{facebook} Session state: FBSessionStateCreatedOpening");
            break;
        default:
			NSLog(@"{facebook} Unkown session state: %d", (int)state);
            break;
    }

	if (error) {
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"facebookError",@"name",
											  error.localizedDescription,@"description",
											  nil]];
	}
}

- (void) openSession:(BOOL)allowLoginUI {
	// Request Email read permission
	NSArray *permissions = [[NSArray alloc] initWithObjects:
							@"email",
							nil];

    [FBSession openActiveSessionWithReadPermissions:permissions
                                       allowLoginUI:allowLoginUI
                                  completionHandler:
	 ^(FBSession *session,
	   FBSessionState state, NSError *error) {
		 // React to session state change
		 [self sessionStateChanged:session state:state error:error];
	 }];
}

- (void) initializeWithManifest:(NSDictionary *)manifest appDelegate:(TeaLeafAppDelegate *)appDelegate {
	@try {
		if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
			// Yes, so just open the session (this won't display any UX).
			[self openSession:NO];
		}
	}
	@catch (NSException *exception) {
		NSLog(@"{facebook} Exception while initializing: %@", exception);
	}
}

- (void) applicationWillTerminate:(UIApplication *)app {
	@try {
		[FBSession.activeSession close];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

- (void) applicationDidBecomeActive:(UIApplication *)app {
	@try {
		[FBAppCall handleDidBecomeActive];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

- (void) handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
	@try {
		[FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

- (void) login:(NSDictionary *)jsonObject {
	@try {
		// If already open,
		if (FBSession.activeSession.isOpen) {
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookState",@"name",
												  @"open",@"state",
												  nil]];
		} else {
			// Open session with UI=YES
			[self openSession:YES];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

- (void) isOpen:(NSDictionary *)jsonObject {
	@try {
		// If open,
		if (FBSession.activeSession.isOpen) {
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookState",@"name",
												  @"open",@"state",
												  nil]];
		} else {
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookState",@"name",
												  @"closed",@"state",
												  nil]];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

- (void) getMe:(NSDictionary *)jsonObject {
	@try {
		if (FBSession.activeSession.isOpen) {
			[[FBRequest requestForMe] startWithCompletionHandler:
			 ^(FBRequestConnection *connection,
			   NSDictionary<FBGraphUser> *user,
			   NSError *error) {
				 if (!error) {
					 NSString *email = [user valueForKey:@"email"];

					 [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														   @"facebookMe",@"name",
														   kCFBooleanFalse, @"error",
														   [NSDictionary dictionaryWithObjectsAndKeys:
															user.id,@"id",
														   [NSString stringWithFormat:@"http://graph.facebook.com/%@/picture", user.id],@"photo_url",
														   user.name,@"name",
														   (email != nil ? email : [NSNull null]),@"email",
														   user.first_name,@"first_name",
														   user.middle_name,@"middle_name",
														   user.last_name,@"last_name",
														   user.link,@"link",
														   user.username,@"username",
														   user.birthday,@"birthday",
														   (user.location != nil ? user.location.id : [NSNull null]),@"location_id",
														   (user.location != nil ? user.location.name : [NSNull null]),@"location_name",
															nil], @"user",
														   nil]];
				 } else {
					 [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														   @"facebookMe",@"name",
														   error.localizedDescription, @"error",
														   nil]];
				 }
			 }];
		} else {
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookMe",@"name",
												  @"closed", @"error",
												  nil]];
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookState",@"name",
												  @"closed",@"state",
												  nil]];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

- (void) getFriends:(NSDictionary *)jsonObject {
	@try {
		if (FBSession.activeSession.isOpen) {
			[[FBRequest requestForMyFriends] startWithCompletionHandler:
			 ^(FBRequestConnection *connection,
			   NSDictionary *result,
			   NSError *error) {
				 if (!error) {
					 // Convert friends data to NSObjects for serialization to JSON
					 NSArray *friends = [result objectForKey:@"data"];
					 NSMutableArray *resp = [NSMutableArray arrayWithCapacity:friends.count];

					 int index = 0;
					 for (NSDictionary<FBGraphUser> *user in friends) {
						 NSString *email = [user valueForKey:@"email"];
						 [resp setObject:[NSDictionary dictionaryWithObjectsAndKeys:
										  user.id,@"id",
										  [NSString stringWithFormat:@"http://graph.facebook.com/%@/picture", user.id],@"photo_url",
										  user.name,@"name",
										  (email != nil ? email : [NSNull null]),@"email",
										  user.first_name,@"first_name",
										  user.middle_name,@"middle_name",
										  user.last_name,@"last_name",
										  user.link,@"link",
										  user.username,@"username",
										  user.birthday,@"birthday",
										  (user.location != nil ? user.location.id : [NSNull null]),@"location_id",
										  (user.location != nil ? user.location.name : [NSNull null]),@"location_name",
										  nil] atIndexedSubscript:index++];
					 }

					 [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														   @"facebookFriends",@"name",
														   kCFBooleanFalse, @"error",
														   resp,@"friends",
														   nil]];
				 } else {
					 [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														   @"facebookFriends",@"name",
														   error.localizedDescription, @"error",
														   nil]];
				 }
			 }];
		} else {
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookFriends",@"name",
												  @"closed", @"error",
												  nil]];
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookState",@"name",
												  @"closed",@"state",
												  nil]];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

- (void) logout:(NSDictionary *)jsonObject {
	@try {
		[FBSession.activeSession closeAndClearTokenInformation];
		[FBSession setActiveSession:nil];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: ", exception);
	}
}

@end

