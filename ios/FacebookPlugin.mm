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

bool bHaveRequestedPublishPermissions = false;

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
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) applicationDidBecomeActive:(UIApplication *)app {
	@try {
		[FBAppCall handleDidBecomeActive];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
	@try {
		[FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

- (void) didBecomeActive:(NSDictionary *)jsonObject {
	[FBSession.activeSession handleDidBecomeActive];
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

- (void) getPublishPermissions:(NSString *)dummyString {
    NSArray *permissions = [[NSArray alloc] initWithObjects:@"publish_actions", nil];
    [[FBSession activeSession] requestNewPublishPermissions:permissions defaultAudience:FBSessionDefaultAudienceFriends completionHandler:^(FBSession *session, NSError *error) {
    	bHaveRequestedPublishPermissions = true;
    }];
}

- (void) publishStory:(NSDictionary *)jsonObject {
	//Open Graph Calls
	// We need to request write permissions from Facebook
    NSString *queryString =  [NSString stringWithFormat:@"?method=POST"];

	for (id key in jsonObject) {
		NSString *temp;
		id o = [jsonObject objectForKey:key];
		if([key isEqual:@"app_namespace"]){
            NSLog(@"app_namespace found");
			continue;
        }
		if([key isEqual:@"actionName"]){
            NSLog(@"actionName found");
			continue;
        }
        NSString *escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) o, NULL,CFSTR("!*'();:@&=+$,/?%#[]"),kCFStringEncodingUTF8);
        temp = [queryString stringByAppendingString:[NSString stringWithFormat:@"&%@=%@",(NSString *) key,escapedString]];
        NSLog(@"The temp string: %@",temp);
		queryString = temp;
		NSLog(@"The part query string: %@",queryString);
	}
    NSLog(@"The query string: %@",queryString);

    NSLog(@"+++++++++++++++++++++======== %@",bHaveRequestedPublishPermissions);

    if( bHaveRequestedPublishPermissions && [FBSession.activeSession.permissions indexOfObject:@"publish_actions"] == NSNotFound)
    {
    	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														  @"facebookOg",@"name",
														  @"rejected",@"error",
														  nil]];	
    	return;
    }
    if ([FBSession.activeSession.permissions indexOfObject:@"publish_actions"] != NSNotFound)
    {
        //[FBSession setActiveSession:session];
        if (FBSession.activeSession != nil && FBSession.activeSession.isOpen) {
            NSLog(@"Reauthorized with publish permissions.");
            NSLog(@"%@",[NSString stringWithFormat:@"me/%@:%@%@",[jsonObject valueForKey:@"app_namespace"], [jsonObject valueForKey:@"actionName"], queryString]);
		    FBRequest* newAction = [[FBRequest alloc]initForPostWithSession:[FBSession activeSession] graphPath:[NSString stringWithFormat:@"me/%@:%@%@",[jsonObject valueForKey:@"app_namespace"], [jsonObject valueForKey:@"actionName"], queryString] graphObject:nil];
		    FBRequestConnection* conn = [[FBRequestConnection alloc] init];
		    [conn addRequest:newAction completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
		    	if(error) {
		    		NSLog(@"Sending OG Story Failed: %@", [error localizedDescription]);
					[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
														  @"facebookOg",@"name",
														  error.localizedDescription,@"error",
														  nil]];
		    		return;
		  		}
		    	NSLog(@"OG action ID: %@", result[@"id"]);
				[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
													  @"facebookOg",@"name",
                            			              kCFBooleanFalse,@"error",
                                        			  (result != nil ? result : [NSNull null]),@"result",
                                                      nil]];	    	
		    }];
		    [conn start];
        }
    }
    else
    {
    	[self getPublishPermissions:@"dummy arg"];
    }
}

- (void) sendRequests:(NSDictionary *)jsonObject {
	//Friend Request Intended.
    NSMutableDictionary* params =   [NSMutableDictionary dictionaryWithObjectsAndKeys:nil]; 
    if([jsonObject objectForKey:@"to"]){
    	[params setValue:[jsonObject valueForKey:@"to"] forKey:@"to"];
    } else if([jsonObject objectForKey:@"suggestedFriends"]){
    	[params setValue:[jsonObject valueForKey:@"to"] forKey:@"suggestedFriends"];
    } 
    if([jsonObject objectForKey:@"link"]){
    	[params setValue:[jsonObject valueForKey:@"link"] forKey:@"link"];
    }       
    [FBWebDialogs presentRequestsDialogModallyWithSession:nil
                  message:[jsonObject valueForKey:@"message"]
                  title:nil
                  parameters:params
                  handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
                      if (error) {
                          // Case A: Error launching the dialog or sending request.
                          NSLog(@"Error sending request.");
                      } else {
                          if (result == FBWebDialogResultDialogNotCompleted) {
                              // Case B: User clicked the "x" icon
                              NSLog(@"User canceled request.");
                          } else {
                              NSLog(@"Request Sent.");
                      }
    }}];
}

- (void) fql:(NSDictionary *)jsonObject {
		NSLOG(@"{facebook} Executing the FQL");
        @try {
                // If already open,
                if (FBSession.activeSession != nil && FBSession.activeSession.isOpen) {
				    NSString *query = [jsonObject valueForKey:@"query"];
				    NSLOG(@"{facebook} Session Opened and query is: %@",[jsonObject valueForKey:@"query"]);
				    // Set up the query parameter
				    NSDictionary *queryParam = @{ @"q": query };
				    // Make the API request that uses FQL
				    [FBRequestConnection startWithGraphPath:@"/fql"
				                                 parameters:queryParam
				                                 HTTPMethod:@"GET"
				                          completionHandler:^(FBRequestConnection *connection,
				                                              id result,
				                                              NSError *error) {
				        if (error) {
				        	NSLOG(@"{facebook} Error Encountered in doing the query!");
				            [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
																  @"facebookFql",@"name",
														   		  error.localizedDescription,@"error",
														   		  nil]];
				        } else {
				            //Send back output to Plugin JS Side
                        	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                            			                         @"facebookFql",@"name",
                                        			             kCFBooleanFalse,@"error",
                                                    			 (result != nil ? result : [NSNull null]),@"user",
                                                                 nil]];
				        }
				    }];
                } else {
                        // Open session with UI=YES
                        [self openSession:YES];
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
						user.location.location.city,@"city",
						user.location.location.country,@"country",
						user.location.location.latitude,@"latitude",
						user.location.location.longitude,@"longitude",
						user.location.location.state,@"state",
						user.location.location.street,@"street",
						user.location.location.zip,@"zip",
						nil];
		}
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
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
        FBSession *session = [FBSession activeSession];
			if (session != nil) {
				[session closeAndClearTokenInformation];
					[FBSession setActiveSession:session];
			}			
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

@end

