#import "FacebookPlugin.h"

@implementation FacebookPlugin

bool sentInitialState = false;

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

	if (FB_ISSESSIONSTATETERMINAL(state)) {
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
}

- (void) openSession:(BOOL)allowLoginUI withRequestId:(NSNumber *)requestId {
	// Request Email read permission
	NSArray *permissions = [[NSArray alloc] initWithObjects:
							@"email",
                            @"public_profile",
                            @"user_friends",
							nil];

	[FBSession openActiveSessionWithReadPermissions:permissions
									   allowLoginUI:allowLoginUI
								  completionHandler:
	 ^(FBSession *session,
	   FBSessionState state, NSError *error) {

        [FBSession setActiveSession:session];
		 // React to session state change
         [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:FB_ISSESSIONOPENWITHSTATE(state) ? @"open" : @"closed", @"state", nil]
                                       withError:nil
                                    andRequestId:requestId];

         [self sessionStateChanged:session state:state error:error];
	 }];

    if (FBSession.activeSession != nil) {
        [FBSession.activeSession addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:NULL];
    }

    if (!sentInitialState) {
        sentInitialState = true;
        [self dispatchSessionState];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"state"] && [object isKindOfClass:[FBSession class]]) {
        if (object != FBSession.activeSession) {
            [object removeObserver:self];
        } else {
            [self dispatchSessionState];
        }
    }
}

- (void)dispatchSessionState {
    if (FBSession.activeSession != nil) {
        NSString *status;
        switch (FBSession.activeSession.state) {
            /*! One of two initial states indicating that no valid cached token was found */
            case FBSessionStateCreated:
                status = @"unknown";
                break;

            /*! One of two initial session states indicating that a cached token was loaded;
             when a session is in this state, a call to open* will result in an open session,
             without UX or app-switching*/
            case FBSessionStateCreatedTokenLoaded:
                // we automatically log you in in this case, so state is essentially connected

            /*! One of three pre-open session states indicating that an attempt to open the session
             is underway*/
            case FBSessionStateCreatedOpening:

            /*! Open session state indicating user has logged in or a cached token is available */
            case FBSessionStateOpen:

            /*! Open session state indicating token has been extended */
            case FBSessionStateOpenTokenExtended:
                // assume connected until further notice
                status = @"connected";
                break;

            /*! Closed session state indicating that a login attempt failed */
            case FBSessionStateClosedLoginFailed:
                status = @"not_authorized";
                break;

            /*! Closed session state indicating that the session was closed, but the users token
             remains cached on the device for later use */
            case FBSessionStateClosed:
                status = @"closed";
                break;
        }

        [[PluginManager get] dispatchEvent:@"_statusChanged" forPlugin:self withData: [NSDictionary dictionaryWithObjectsAndKeys:status, @"status", nil]];
    }
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
			[self openSession:NO withRequestId:[NSNumber numberWithInt:0]];
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

- (void) login:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
	@try {
		// If already open,
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
            [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:@"open",@"state", nil] withError:nil andRequestId:requestId];
		} else {
			// Open session with UI=YES
			[self openSession:YES withRequestId:requestId];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) isOpen:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
	@try {
		// If open,
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
            [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:@"open",@"state", nil] withError:nil andRequestId:requestId];
		} else {
            [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:@"closed",@"state", nil] withError:nil andRequestId:requestId];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
        [[PluginManager get] dispatchJSResponse:nil withError:[NSString stringWithFormat:@"%@: %@", [exception name], [exception description]] andRequestId:requestId];
	}
}

-(void) setState:(NSString *)state {
    [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                                          @"facebookState",@"name",
                                          @"closed",@"state",
                                          nil]];

}

- (void) fql:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
	@try {
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {

            NSDictionary *queryParam = @{ @"q": [jsonObject objectForKey:@"query"] };
            [FBRequestConnection startWithGraphPath:@"/fql"
                                         parameters:queryParam
                                         HTTPMethod:@"GET" completionHandler:
			 ^(FBRequestConnection *connection,
               id result,
			   NSError *error) {
                 [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithDictionary:result]
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

- (void) getMe:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
	@try {
		if (FBSession.activeSession != nil &&
			FBSession.activeSession.isOpen) {
			[[FBRequest requestForMe] startWithCompletionHandler:
			 ^(FBRequestConnection *connection,
			   NSDictionary<FBGraphUser> *user,
			   NSError *error) {
                 [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          [NSDictionary dictionaryWithDictionary:user],@"user",
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
						 [listResult setObject:[NSDictionary dictionaryWithDictionary:user] atIndexedSubscript:index++];
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

- (void) inviteFriends:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId{
	@try {
		[FBWebDialogs
			presentRequestsDialogModallyWithSession:nil
			message:[jsonObject objectForKey:@"message"]
			title:[jsonObject objectForKey:@"title"]
			parameters:nil
			handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
                [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:
                                                         result == FBWebDialogResultDialogCompleted ? @true : @false, @"completed",
                                                         [resultURL absoluteString], @"resultURL",
                                                         nil]
                                              withError:error
                                           andRequestId:requestId];
			}
		];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) logout:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
	@try {
		if (FBSession.activeSession != nil) {
			[FBSession.activeSession closeAndClearTokenInformation];
			[FBSession setActiveSession:nil];
		}

        [[PluginManager get] dispatchJSResponse: [NSDictionary dictionaryWithObjectsAndKeys:@"closed", @"state", nil] withError: nil andRequestId:requestId];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

@end

