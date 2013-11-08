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
        [self setState:@"open"];
	} else if (FB_ISSESSIONSTATETERMINAL(state)) {
        [self setState:@"closed"];

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
			NSLog(@"{facebook} Unknown session state: %d", (int)state);
			break;
	}

	if (error) {
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"plugins",@"name",
                                              @"FacebookPlugin",@"plugin",
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
		NSRange range = [url.query rangeOfString:@"notif" options:NSCaseInsensitiveSearch];

		// If the url's query contains 'notif', we know it's coming from a notification - let's process it
		if(url.query && range.location != NSNotFound) {
			// Yes the incoming URL was a notification
			[self processIncomingRequest: url];
		} else {
			[FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing openurl event: %@", exception);
	}
}

- (void) processIncomingRequest: (NSURL *) url {
	// Extract the notification id
	NSArray *pairs = [url.query componentsSeparatedByString:@"&"];
    NSURL *targetURL = nil;
	for (NSString *pair in pairs) {
		NSArray *kv = [pair componentsSeparatedByString:@"="];
        if ([[kv objectAtIndex:0] isEqualToString:@"target_url"]) {
            NSString *decodedURL = [[kv objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            targetURL = [NSURL URLWithString:decodedURL];
            break;
        }
	}
    if (targetURL != nil) {
        NSArray * pairs = [targetURL.query componentsSeparatedByString:@"&"];
        NSMutableDictionary *targetQueryParams = [[NSMutableDictionary alloc] init];
        for (NSString *pair in pairs) {
            NSArray *kv = [pair componentsSeparatedByString:@"="];
            NSString *val = [[kv objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            [targetQueryParams setObject:val forKey:[kv objectAtIndex:0]];
        }
        
        NSString *requestIDsString = [targetQueryParams objectForKey:@"request_ids"];
        NSArray *requestIDs = [requestIDsString componentsSeparatedByString:@","];
        FBRequest *req = [[FBRequest alloc] initWithSession:[FBSession activeSession] graphPath:[requestIDs objectAtIndex:0]];
        
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error)
         {
             NSString *data = [result objectForKey:@"data"];
             NSString *from = [result objectForKey:@"from"];
             NSString *requestID = [result objectForKey:@"id"];
			 NSString *message = [result objectForKey:@"message"];
             [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                                                   @"facebookRequest", @"name",
                                                   data ? data : @"", @"data",
                                                   from ? from : @"", @"from",
                                                   requestID ? requestID : @"", @"id",
												   message ? message : @"", @"message",
                                                   error ? error.localizedDescription : false, @"error",
                                                   nil]];
             
             [FBRequestConnection startWithGraphPath:requestID
                                          parameters:nil
                                          HTTPMethod:@"DELETE"
                                   completionHandler:^(FBRequestConnection *connection,
                                                       id result,
                                                       NSError *error) {
                                       if (!error) {
                                           NSLog(@"Request deleted");
                                       }
                                       //TODO notify JS?
                                   }];
             
         }];
        

    } else {
        NSLOG(@"Error getting targetURL from %@", url);
    }

}

- (void) login:(NSDictionary *)jsonObject {
	@try {
		// If already open,
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
            [self setState:@"open"];
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
            [self setState:@"open"];
		} else {
            [self setState:@"closed"];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

-(void) setState:(NSString *)state {
    [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                                          @"facebookState",@"name",
                                          @"closed",@"state",
                                          nil]];
    
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

- (void) getMe:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
	@try {
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
			[[FBRequest requestForMe] startWithCompletionHandler:
			 ^(FBRequestConnection *connection,
			   NSDictionary<FBGraphUser> *user,
			   NSError *error) {
                 NSDictionary *userDict = wrapGraphUser(user);
                 [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          (userDict != nil ? userDict : [NSNull null]),@"user",
                                                          nil]
                                               withError:error andRequestId:requestId];
			 }];
		} else {
            
			[[PluginManager get] dispatchJSResponse:nil
                                          withError:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     @"closed",@"error",
                                                     nil]
                                       andRequestId: requestId];

            [self setState:@"closed"];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) getFriends:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
	@try {
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
			[[FBRequest requestForMyFriends] startWithCompletionHandler:
			 ^(FBRequestConnection *connection,
			   NSDictionary *result,
			   NSError *error) {
                 NSDictionary *response = nil;
				 if (!error) {
					 // Convert friends data to NSObjects for serialization to JSON
					 NSArray *friends = [result objectForKey:@"data"];
                    NSMutableArray *listResult = [NSMutableArray arrayWithCapacity:friends.count];

					 int index = 0;
					 for (NSDictionary<FBGraphUser> *user in friends) {
						 NSDictionary *result = wrapGraphUser(user);

						 [listResult setObject:(result != nil ? result : [NSNull null]) atIndexedSubscript:index++];
					 }
                     
                     response = [NSDictionary dictionaryWithObjectsAndKeys:
                             listResult,@"friends",
                             nil];
                 }
                 
                 [[PluginManager get] dispatchJSResponse:response withError:error andRequestId:requestId];
			 }];
		} else {
			[[PluginManager get] dispatchJSResponse:nil withError: [NSDictionary dictionaryWithObjectsAndKeys:
												  @"closed",@"error",
												  nil] andRequestId:requestId];
            [self setState:@"closed"];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) postStory:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
    // Invoke the dialog
    [FBWebDialogs presentFeedDialogModallyWithSession:nil
                                           parameters:jsonObject
                                              handler:
     ^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
         // Handle the publish feed callback
         [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  result == FBWebDialogResultDialogCompleted ? @true : @false, @"completed",
                                                  [resultURL absoluteString], @"resultURL",
                                                  nil]
                                       withError:error
                                    andRequestId:requestId];
     }];
}

- (void) inviteFriends:(NSDictionary *)jsonObject {
	@try {
		[FBWebDialogs
			presentRequestsDialogModallyWithSession:nil
			message:[jsonObject objectForKey:@"message"]
			title:[jsonObject objectForKey:@"title"]
			parameters:nil
			handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
				if (result == FBWebDialogResultDialogCompleted) {
					[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          @"facebookInvites",@"name",
                                                          error ? error.localizedDescription : @false, @"error",
                                                          @true,@"completed",
                                                          [resultURL absoluteString], @"resultURL",
                                                          nil]];
				} else {
					[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          @"facebookInvites",@"name",
						   error.localizedDescription, @"error",
                           @false, @"completed",
						   nil]];
				}
			}
		];
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

