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

	self.bHaveRequestedPublishPermissions = false;
	return self;
}

- (void) sessionStateChanged:(FBSession *)session state:(FBSessionState) state
	error:(NSError *)error {


	if (error) {
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
			@"facebookError",@"name",
			error.localizedDescription,@"description",
			nil]];
	}

	// If state indicates the session is open,
	if (FB_ISSESSIONOPENWITHSTATE(state)) {
		// Notify JS
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
			@"facebookState",@"name",
			@"open",@"state",
			nil]];
	} else if (FB_ISSESSIONSTATETERMINAL(state)) {
		self.bHaveRequestedPublishPermissions = false;
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
			@"facebookState",@"name",
			@"closed",@"state",
			[FBErrorUtility userMessageForError:error], @"error",
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

- (void) reLogin:(NSString *)dummyString {
	[self login:[NSDictionary dictionaryWithObjectsAndKeys:nil]];
	return;
}

- (void) getPublishPermissions:(NSString *)dummyString {

	if (FBSession.activeSession == nil || !FBSession.activeSession.isOpen) {
		[self reLogin:@"dummyString"];
		return;
	}
	[FBSession.activeSession
		requestNewPublishPermissions:[NSArray arrayWithObject:@"publish_actions"]
		defaultAudience:FBSessionDefaultAudienceEveryone
		completionHandler:^(FBSession *session, NSError *error) {
			self.bHaveRequestedPublishPermissions = true;
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
			continue;
		}
		if([key isEqual:@"actionName"]){
			continue;
		}
		NSString *escapedString = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,(CFStringRef) o, NULL,CFSTR("!*'();:@&=+$,/?%#[]"),kCFStringEncodingUTF8);
		temp = [queryString stringByAppendingString:[NSString stringWithFormat:@"&%@=%@",(NSString *) key,escapedString]];
		queryString = temp;
	}

	if( ((int) self.bHaveRequestedPublishPermissions) && [FBSession.activeSession.permissions indexOfObject:@"publish_actions"] == NSNotFound)
	{
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
			@"facebookOg",@"name",
			@"rejected",@"error",
			nil]];
		return;
	}
	if ([FBSession.activeSession.permissions indexOfObject:@"publish_actions"] != NSNotFound)
	{
		if (FBSession.activeSession != nil && FBSession.activeSession.isOpen) {
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

/**
 * A function for parsing URL parameters.
 */
- (NSDictionary*)parseURLParams:(NSString *)query {
	NSString * eStr = [query stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSArray *pairs = [eStr componentsSeparatedByString:@"&"];
	NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
	for (NSString *pair in pairs) {
		NSArray *kv = [pair componentsSeparatedByString:@"="];
		NSString *val =
			[kv[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		params[kv[0]] = val;
	}
	return params;
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
					NSDictionary *urlParams = [self parseURLParams:[resultURL query]];
					//fbconnect://success?request=1455632271325417&to%5B0%5D=1123869872
					//fbconnect://success?request=225532777570701&to%5B0%5D=1123869872&to%5B1%5D=100001558865936
					NSMutableDictionary *ret = [[NSMutableDictionary alloc] init];
					[ret setValue:urlParams forKey: @"mMap"];
					[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
						@"facebookRequest",@"name",
						ret, @"response",
						nil]];
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
							([NSString stringWithFormat:@"%@",[result objectForKey:@"data"]] != nil ? [result objectForKey:@"data"] : [NSNull null]),@"result",
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

- (void) newCATPIR: (NSDictionary *)jsonObject {
	[FBRequestConnection startForCustomAudienceThirdPartyID:nil
		completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
			NSString *id = error ? nil : [result objectForKey:@"custom_audience_third_party_id"];
			// Stash off this id, send it to your server, etc.  Use later to construct
			// a custom audience.  A result of 'nil' means that either the user can't be
			// identified, or they've limited ad tracking via iOS 6.
			if(error)
			{
				[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
					@"facebooknewCATPI",@"name",
					error.localizedDescription,@"error",
					nil]];
				return;
			}
			NSLOG(@"{facebook} The CATPI is %@", id);
			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
				@"facebooknewCATPI",@"name",
				kCFBooleanFalse,@"error",
				id,@"result",
				nil]];
		}
	];	
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
			self.bHaveRequestedPublishPermissions = false;
		}			
	}
	@catch (NSException *exception) {
		NSLOG(@"{facebook} Exception while processing event: %@", exception);
	}
}

@end

