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

// -----------------------------------------------------------------------------
// EXPOSED PLUGIN METHODS
// -----------------------------------------------------------------------------

- (void) init:(NSDictionary *)opts {
    NSString *appID = [json objectForKey:@"appID"];
    NSString *displayName = [json objectForKey:@"displayName"];

    [FBSettings setDefaultAppID:appID];
    [FBSettings setDefaultDisplayName:displayName];

    NSLog(@"{facebook} SET DEFAULTS %@ %@", appID, displayName);

    return @"{\"status\": \"ok\"}";
}

- (void) login:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {

}

- (void) ui:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {

}

- (void) logout:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {
  @try {
    if (FBSession.activeSession != nil) {
      [FBSession.activeSession closeAndClearTokenInformation];
      [FBSession setActiveSession:nil];
    }

    [[PluginManager get] dispatchJSResponse: [NSDictionary dictionaryWithObjectsAndKeys:@"closed", @"state", nil] withError: nil andRequestId:requestId];
  }
  @catch (NSException *exception) {
    [[PluginManager get] dispatchJSResponse: [NSDictionary dictionaryWithObjectsAndKeys:@"closed", @"error", nil] withError: nil andRequestId:requestId];
    NSLOG(@"{facebook} Exception while processing event: %@", exception);
  }
}

- (void) api:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {
  NSString * path = [opts valueForKey:@"path"];
  NSString * method = [[opts valueForKey:@"method"] uppercaseString];
  NSDictionary * params = [opts objectForKey:@"params"];

  [FBRequestConnection startWithGraphPath:path
                               parameters:params
                               HTTPMethod:method
                        completionHandler:^(FBRequestConnection *conn, id result, NSError * error) {
                          // Result should be either an array or a dictionary
                          NSDictionary * res;

                          if (error) {
                            res = [NSDictionary dictionaryWithObjectsAndKeys: error, @"error"];
                          } else if ([id isKindOfClass:[NSArray class]]) {
                            // Array
                            res = [NSDictionary dictionaryWithObjectsAndKeys: [result data], @"data"];
                          } else {
                            // dictionary
                            res = [result data];
                          }

                          [[PluginManager get] dispatchJSResponse:response
                                                        withError:nil
                                                     andRequestId:requestId];
                        }];
}

- (void) getLoginStatus:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {

}

- (void) getAuthResponse:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {

}

// -----------------------------------------------------------------------------
// HELPER FUNCTIONS
// -----------------------------------------------------------------------------

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

- (void) login:(NSDictionary *)opts withRequestId:(NSNumber *)requestId
{
  NSArray * permissions = [opts valueForKey:@"scope"];

  // Whenever a person opens the app, check for a cached session
  if (FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {

    // If there's one, just open the session silently, without showing the user
    // the login UI
    [FBSession
      openActiveSessionWithReadPermissions:permissions
      allowLoginUI:NO
      completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
        // Handler for session state changes This method will be called EACH
        // time the session state changes, also for intermediate states and NOT
        // just when the session open
        [self sessionStateChanged:session state:state error:error];
      }];
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

        [[PluginManager get] dispatchEvent:@"Facebook.auth.statusChange"
                                 forPlugin:self
                                 withData: [NSDictionary dictionaryWithObjectsAndKeys:status, @"status", nil]];
    }
}

- (void) login:(NSDictionary *)jsonObject withRequestId:(NSNumber *)requestId {
  @try {
    if (FBSession.activeSession != nil &&
        FBSession.activeSession.isOpen) {
      // If already open,
      [[PluginManager get] dispatchJSResponse:[NSDictionary dictionaryWithObjectsAndKeys:@"open",@"state", nil] withError:nil andRequestId:requestId];
    } else if (FBSession.activeSession != nil &&
        FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
      // If logged in, just open the session with UI=NO
      [self openSession:NO withRequestId:requestId];
    } else {
      // Open session with UI=YES
      [self openSession:YES withRequestId:requestId];
    }
  }
  @catch (NSException *exception) {
    NSLOG(@"{facebook} Exception while processing event: %@", exception);
  }
}

// -----------------------------------------------------------------------------
// GC PLUGIN INTERFACE
// -----------------------------------------------------------------------------


- (void) initializeWithManifest:(NSDictionary *)manifest appDelegate:(TeaLeafAppDelegate *)appDelegate {
  @try {
    self.ms_friendCache = nil;

    if (FBSession.activeSession != nil &&
        FBSession.activeSession.state == FBSessionStateCreatedTokenLoaded) {
      // Yes, so just open the session (this won't display any UX).
      [self openSession:NO withRequestId:[NSNumber numberWithInt:0]];
    }

  }
  @catch (NSException *exception) {
    NSLog(@"{facebook} Exception while initializing: %@", exception);
  }


  [[PluginManager get] dispatchEvent:@"FacebookPluginReady"
                           forPlugin:self
                            withData:[NSDictionary dictionaryWithObjectsAndKeys:@"ok", @"status", nil]]]
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
      [FBAppCall handleOpenURL:url sourceApplication:sourceApplication];
    }
  }
  @catch (NSException *exception) {
    NSLOG(@"{facebook} Exception while processing openurl event: %@", exception);
  }
}

// -----------------------------------------------------------------------------
// TO BE REMOVED
// -----------------------------------------------------------------------------

-(void) setState:(NSString *)state {
    [[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
                                          @"facebookState",@"name",
                                          @"closed",@"state",
                                          nil]];

}


@end
