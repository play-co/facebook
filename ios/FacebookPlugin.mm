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

		if (FBSession.activeSession != nil) {
			[FBSession.activeSession closeAndClearTokenInformation];
			[FBSession setActiveSession:nil];
		}
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
		// NOTE: Should not need this since we inject it into the Info.plist
		NSDictionary *ios = [manifest valueForKey:@"ios"];
		NSString *facebookAppID = [ios valueForKey:@"facebookAppID"];
		if (facebookAppID) {
			[FBSettings setDefaultAppID:facebookAppID];
		}

		if (FBSession.activeSession != nil &&
			FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
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
		if (FBSession.activeSession != nil) {
			[FBSession.activeSession close];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing terminate event: %@", exception);
	}
}

- (void) applicationDidBecomeActive:(UIApplication *)app {
	@try {
		// Track app active event with Facebook app analytics
		[FBAppEvents activateApp];

		[FBAppCall handleDidBecomeActive];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing active event: %@", exception);
	}
}

- (void) handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
	@try {
		[FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing openurl event: %@", exception);
	}
}

- (void) login:(NSDictionary *)jsonObject {
	@try {
		// If already open,
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
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
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) isOpen:(NSDictionary *)jsonObject {
	@try {
		// If open,
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
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
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

static NSDictionary *wrapGraphUser(NSDictionary<FBGraphUser> *user) {
	NSString *email = [user valueForKey:@"email"];
	
	NSDictionary *location = nil;
	if (user.location != nil) {
		if (user.location.location != nil) {
			location = [NSDictionary dictionaryWithObjectsAndKeys:
						[user.location.location objectForKey:@"city"],@"city",
						[user.location.location objectForKey:@"country"],@"country",
						[user.location.location objectForKey:@"latitude"],@"latitude",
						[user.location.location objectForKey:@"longitude"],@"longitude",
						[user.location.location objectForKey:@"state"],@"state",
						[user.location.location objectForKey:@"street"],@"street",
						[user.location.location objectForKey:@"zip"],@"zip",
						nil];
		}
	}

	return [NSDictionary dictionaryWithObjectsAndKeys:
									[user objectForKey:@"id"],@"id",
									[NSString stringWithFormat:@"http://graph.facebook.com/%@/picture", [user objectForKey:@"id"]],@"photo_url",
									[user objectForKey:@"name"],@"name",
									(email != nil ? email : [NSNull null]),@"email",
									[user objectForKey:@"first_name"],@"first_name",
									[user objectForKey:@"middle_name"],@"middle_name",
									[user objectForKey:@"last_name"],@"last_name",
									[user objectForKey:@"link"],@"link",
									[user objectForKey:@"username"],@"username",
									[user objectForKey:@"birthday"],@"birthday",
									(location != nil ? location : [NSNull null]),@"location",
									nil];
}

- (void) getMe:(NSDictionary *)jsonObject {
	@try {
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
			[[FBRequest requestForMe] startWithCompletionHandler:
			 ^(FBRequestConnection *connection,
			   NSDictionary<FBGraphUser> *user,
			   NSError *error) {
				 if (!error) {
					 NSDictionary *result = wrapGraphUser(user);

					 [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														   @"facebookMe",@"name",
														   kCFBooleanFalse,@"error",
														   (result != nil ? result : [NSNull null]),@"user",
														   nil]];
				 } else {
					 [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														   @"facebookMe",@"name",
														   error.localizedDescription,@"error",
														   nil]];
				 }
			 }];
		} else {
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookMe",@"name",
												  @"closed",@"error",
												  nil]];
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookState",@"name",
												  @"closed",@"state",
												  nil]];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) getFriends:(NSDictionary *)jsonObject {
	@try {
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
			[[FBRequest requestForMyFriends] startWithCompletionHandler:
			 ^(FBRequestConnection *connection,
			   NSDictionary *result,
			   NSError *error) {
				 if (!error) {
					 // Convert friends data to NSObjects for serialization to JSON
					 NSArray *friends = [result objectForKey:@"data"];
					 NSMutableArray *listResult = [NSMutableArray arrayWithCapacity:friends.count];

					 int index = 0;
					 for (NSDictionary<FBGraphUser> *user in friends) {
						 NSDictionary *result = wrapGraphUser(user);

						 [listResult setObject:(result != nil ? result : [NSNull null]) atIndexedSubscript:index++];
					 }

					 [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														   @"facebookFriends",@"name",
														   kCFBooleanFalse,@"error",
														   listResult,@"friends",
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
												  @"closed",@"error",
												  nil]];
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"facebookState",@"name",
												  @"closed",@"state",
												  nil]];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) logout:(NSDictionary *)jsonObject {
	@try {
		if (FBSession.activeSession != nil) {
			[FBSession.activeSession closeAndClearTokenInformation];
			[FBSession setActiveSession:nil];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

@end

