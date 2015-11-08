#import "FacebookPlugin.h"
#import "platform/log.h"
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKShareKit/FBSDKShareKit.h>
#import <FBSDKMessengerShareKit/FBSDKMessengerShareKit.h>

@implementation FacebookPlugin

// -----------------------------------------------------------------------------
// EXPOSED PLUGIN METHODS
// -----------------------------------------------------------------------------

- (NSString *) facebookInit:(NSDictionary *)opts {
    NSLOG(@"{facebook} opts %@", opts);

    // lowercase appId param matches the JS init interface
    NSString *appID = [opts objectForKey:@"appId"];
    NSString *displayName = [opts objectForKey:@"displayName"];

    [FBSDKSettings setAppID:appID];
    [FBSDKSettings setDisplayName:displayName];

    NSNumber *frictionlessRequests = [opts objectForKey:@"frictionlessRequests"];
    frictionlessRequestsEnabled = frictionlessRequests != nil && [frictionlessRequests boolValue] == YES;
    
    NSLOG(@"{facebook} SET DEFAULTS %@ %@", appID, displayName);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAccessTokenDidChange:)
                                                 name:@"FBSDKAccessTokenDidChangeNotification"
                                               object:nil];

    return @"{\"status\": \"ok\"}";
}

- (void) login:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {
    BOOL permissionsAllowed = YES;
    NSString *permissionsErrorMessage = @"";
    NSArray *permissions = [(NSString *)opts[@"scope"] componentsSeparatedByString:@","];

    // save the callbackId for the login callback
    self.loginRequestId = requestId;

    FBSDKAccessToken *token = [FBSDKAccessToken currentAccessToken];
    FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];

    void (^handleLogin)(FBSDKLoginManagerLoginResult *result, NSError *error) = ^void(FBSDKLoginManagerLoginResult *result, NSError *error) {
        [self onLoginResult:result error:error];
    };

    if (token) {
        // remove permissions that the user already has
        permissions = [permissions filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
            return ![token.permissions containsObject:evaluatedObject];
        }]];

        // Reauthorize if the session is already open.
        // In this instance we can ask for publish type
        // or read type only if taking advantage of iOS6.
        // To mix both, we'll use deprecated methods
        BOOL publishPermissionFound = NO;
        BOOL readPermissionFound = NO;
        for (NSString *p in permissions) {
            if ([self isPublishPermission:p]) {
                publishPermissionFound = YES;
            } else {
                readPermissionFound = YES;
            }
        }

        if ([permissions count] == 0) {
            [self onAccessTokenDidChange:nil];
        } else if (publishPermissionFound && readPermissionFound) {
            // Mix of permissions, not allowed
            permissionsAllowed = NO;
            permissionsErrorMessage = @"Your app can't ask for both read and write permissions.";
        } else if (publishPermissionFound) {
            // Only publish permissions
            [login logInWithPublishPermissions:permissions handler:handleLogin];
        } else {
            // Only read permissions
            [login logInWithReadPermissions:permissions handler:handleLogin];
            self.loginRequestId = requestId;
        }
    } else {
        // Initial log in, can only ask for read type permissions
        NSLOG(@"{facebook} requesting initial login");
        if ([self areAllPermissionsReadPermissions:permissions]) {
            [login logInWithReadPermissions:permissions handler:handleLogin];
        } else {
          permissionsAllowed = NO;
          permissionsErrorMessage = @"You can only ask for read permissions initially";
        }
    }

    if (!permissionsAllowed) {
        [[PluginManager get]
          dispatchJSResponse:@{@"error":permissionsErrorMessage}
          withError:nil
          andRequestId:requestId];
        self.loginRequestId = nil;
    }
}

- (void) ui:(NSDictionary *)params withRequestId:(NSNumber *)requestId {

    // Dialog method
    NSString * method;
    if ([params objectForKey:@"method"]) {
        method = [params objectForKey:@"method"];
    } else {
        method = @"apprequests";
    }

    if ([method isEqualToString: @"share_open_graph"]) {
        // TODO: params: action_type, action_properties
        // https://developers.facebook.com/docs/sharing/reference/share-dialog
    } else if ([method isEqualToString: @"share"]) {
        [FBSDKShareDialog showFromViewController:self.tealeafViewController
                                     withContent:[self resolveContentFromParams: params]
                                        delegate:nil];
    } else if ([method isEqualToString: @"send"]) {
        [FBSDKMessageDialog showWithContent:[self resolveContentFromParams: params]
                                   delegate:nil];
    } else if ([method isEqualToString: @"apprequests"]) {
        FBSDKGameRequestDialog *dialog = [[FBSDKGameRequestDialog alloc] init];
        dialog.content = [self resolveGameContentFromParams: params];
        dialog.frictionlessRequestsEnabled = frictionlessRequestsEnabled;
        [dialog show];
    }
}

- (void) resolveFilter:(NSString *)filter intoContent:(FBSDKGameRequestContent*)content {
    if ([filter isEqualToString:@"app_users"]) {
        content.filters = FBSDKGameRequestFilterAppUsers;
    } else if ([filter isEqualToString:@"app_non_users"]) {
        content.filters = FBSDKGameRequestFilterAppNonUsers;
    } else {
        NSLog(@"{facebook} [warn] Facebook Mobile SDK does not support the filter \"%@\". You can only use \"app_users\" or \"app_non_users\".", filter);
    }
}

- (FBSDKGameRequestContent *) resolveGameContentFromParams:(NSDictionary *)params {
    FBSDKGameRequestContent *content = [[FBSDKGameRequestContent alloc] init];
    content.title = [params objectForKey:@"title"];
    content.message = [params objectForKey:@"message"];
    
    NSString *actionType = [params objectForKey:@"action_type"];
    if (actionType) {
        if ([actionType isEqualToString:@"send"]) {
            content.actionType = FBSDKGameRequestActionTypeSend;
            content.objectID = [params objectForKey:@"object_id"];
        } else if ([actionType isEqualToString:@"askfor"]) {
            content.actionType = FBSDKGameRequestActionTypeAskFor;
            content.objectID = [params objectForKey:@"object_id"];
        } else if ([actionType isEqualToString:@"turn"]) {
            content.actionType = FBSDKGameRequestActionTypeTurn;
        }
    }
    
    id filter = [params objectForKey:@"filters"];
    if (filter) {
        if ([filter isKindOfClass:[NSArray class]]) {
            NSArray *filterArray = (NSArray *) filter;
            for (id filterObj in filterArray) {
                if ([filterObj isKindOfClass:[NSString class]]) {
                    [self resolveFilter:filterObj intoContent:content];
                }
            }
        } else if ([filter isKindOfClass:[NSString class]]) {
            [self resolveFilter:filter intoContent:content];
        } else {
            NSLog(@"{facebook} [warn] Facebook Mobile SDK does not support arbitrary filters. Please provide either \"app_users\" or \"app_non_users\".");
        }
    }
    
    NSString *ids = [params objectForKey:@"to"];
    if (ids) {
        content.recipients = [ids componentsSeparatedByString:@","];
    }
    
    NSString *suggestions = [params objectForKey:@"suggestions"];
    if (suggestions) {
        content.recipientSuggestions = [suggestions componentsSeparatedByString:@","];
    }
    
    NSString *excludeIds = [params objectForKey:@"exclude_ids"];
    if (excludeIds) {
        NSLog(@"{facebook} [warn] exclude_ids is not supported in the Facebook Mobile SDK");
    }
    
    NSNumber *maxRecipients = [params objectForKey:@"max_recipients"];
    if (maxRecipients) {
        NSLog(@"{facebook} [warn] max_recipients is not supported in the Facebook Mobile SDK");
    }
    
    content.data = [params objectForKey:@"data"];
    return content;
}

- (id<FBSDKSharingContent>) resolveContentFromParams:(NSDictionary *)params {
    if ([params objectForKey:@"video"]) {
        FBSDKShareVideo *video = [[FBSDKShareVideo alloc] init];
        video.videoURL = [params objectForKey:@"video"];
        FBSDKShareVideoContent *content = [[FBSDKShareVideoContent alloc] init];
        content.video = video;
        return content;
    } else if ([params objectForKey:@"image"]) {
        FBSDKSharePhoto *photo = [FBSDKSharePhoto photoWithImageURL:[params objectForKey:@"image"] userGenerated:YES];
        FBSDKSharePhotoContent *content = [[FBSDKSharePhotoContent alloc] init];
        content.photos = @[photo];
        return content;
    } else if ([params objectForKey:@"href"]) {
        FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        content.contentURL = [params objectForKey:@"href"];
        return content;
    }

    return nil;
}

- (void) logout:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {
    if ([FBSDKAccessToken currentAccessToken]) {
        FBSDKLoginManager *login = [[FBSDKLoginManager alloc] init];
        [login logOut];

        [[PluginManager get]
         dispatchJSResponse: @{@"status": @"logged_out"}
         withError:nil
         andRequestId:requestId];
    } else {
        [[PluginManager get]
         dispatchJSResponse: @{@"status": @"not_logged_in"}
         withError:nil
         andRequestId:requestId];
    }
}

- (void) api:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {

    NSString * path = [opts valueForKey:@"path"];
    NSString * method = [[opts valueForKey:@"method"] uppercaseString];
    NSMutableDictionary * params = [[opts objectForKey:@"params"] mutableCopy];

    if ([FBSDKAccessToken currentAccessToken]) {
        [[[FBSDKGraphRequest alloc] initWithGraphPath:path parameters:params HTTPMethod:method]
         startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
             // Result should be either an array or a dictionary
             NSDictionary * res;

             if (error) {
                 res = [self getErrorResponse:error];
             } else if ([result isKindOfClass:[NSArray class]]) {
                 // Array
                 res = @{@"data": [result data]};
             } else {
                 // dictionary
                 res = (NSDictionary *) result;
             }

             [[PluginManager get]
              dispatchJSResponse:res
              withError:nil
              andRequestId:requestId];
         }];
    }
}

- (void) getLoginStatus:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {
  NSDictionary * loginStatus = [self authResponse];
  [[PluginManager get] dispatchJSResponse:loginStatus withError:nil andRequestId:requestId];
}

- (void) getAuthResponse:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {
  NSDictionary * loginStatus = [self authResponse];
  NSDictionary * authResponse = [loginStatus objectForKey:@"authResponse"];
  [[PluginManager get] dispatchJSResponse:authResponse withError:nil andRequestId:requestId];
}

- (void) shareImage:(NSDictionary *)opts withRequestId:(NSNumber *)requestId {
    UIImage* image = nil;

    if (opts[@"image"]) {
        NSData* imageData = [[NSData alloc] initWithBase64EncodedString:opts[@"image"] options:0];
        image = [[UIImage alloc] initWithData:imageData];

        if ([FBSDKMessengerSharer messengerPlatformCapabilities] & FBSDKMessengerPlatformCapabilityImage) {
            [FBSDKMessengerSharer shareImage:image withOptions:nil];
        }
    }

  [[PluginManager get]
             dispatchJSResponse: @{@"successs": @true}
             withError:nil
             andRequestId:requestId
             ];
}


// -----------------------------------------------------------------------------
// HELPER FUNCTIONS
// -----------------------------------------------------------------------------

- (void) onLoginResult:(FBSDKLoginManagerLoginResult *) result error:(NSError *)error {
    if (error) {
        if (self.loginRequestId) {
            
            [[PluginManager get]
             dispatchJSResponse:nil
             withError:error
             andRequestId:self.loginRequestId];
            self.loginRequestId = nil;
        }
    } else if (result.isCancelled) {
        if (self.loginRequestId) {
            [[PluginManager get]
             dispatchJSResponse: @{@"isCancelled": @true}
             withError:error
             andRequestId:self.loginRequestId];
            self.loginRequestId = nil;
        }
    } else {
        // all other cases are handled by the access token notification
        [self onAccessTokenDidChange:nil];
    }
}

- (void) onAccessTokenDidChange:(NSNotification *)notification {
    NSDictionary * res = [self authResponse];

    [[PluginManager get]
     dispatchEvent:@"auth.authResponseChanged"
     forPlugin:self
     withData:res];

    [[PluginManager get]
     dispatchEvent:@"auth.statusChange"
     forPlugin:self
     withData:res];

    if (self.loginRequestId != nil) {
        [[PluginManager get]
         dispatchJSResponse: res
         withError:nil
         andRequestId:self.loginRequestId];
        self.loginRequestId = nil;
    }
}

- (NSDictionary *) getErrorResponse:(NSError *) error {
    NSMutableDictionary * res = [[NSMutableDictionary alloc] init];
    NSDictionary * userInfo = [error userInfo];

    res[@"error"] = [userInfo
                     [@"com.facebook.sdk:FBSDKGraphRequestErrorParsedJSONResponseKey"]
                     [@"body"]
                     [@"error"] mutableCopy];

    if (userInfo[@"com.facebook.sdk:FBSDKErrorLocalizedDescriptionKey"]) {
        res[@"error"][@"error_user_message"] = userInfo[@"com.facebook.sdk:FBSDKErrorLocalizedDescriptionKey"];
    }

    if (userInfo[@"com.facebook.sdk:FBSDKErrorLocalizedTitleKey"]) {
        res[@"error"][@"error_user_title"] = userInfo[@"com.facebook.sdk:FBSDKErrorLocalizedTitleKey"];
    }

    if (userInfo[@"com.facebook.sdk:com.facebook.sdk:FBSDKErrorDeveloperMessageKey"]) {
        NSLOG(@"{facebook} dev error: %@", userInfo[@"com.facebook.sdk:com.facebook.sdk:FBSDKErrorDeveloperMessageKey"]);
    }

    return res;
}

// Generate the auth response expected by javascript
- (NSDictionary *) authResponse {
    FBSDKAccessToken *token = [FBSDKAccessToken currentAccessToken];
    NSTimeInterval expiresTimeInterval = [token.expirationDate timeIntervalSinceNow];
    NSNumber* expiresIn = @0;
    if (expiresTimeInterval > 0) {
        expiresIn = [NSNumber numberWithDouble:expiresTimeInterval];
    }

    NSString * userID = token ? token.userID : @"";
    if (token) {
        // Build an object that matches the javascript response
        NSDictionary * authData = @{
                                    @"accessToken": token.tokenString,
                                    @"expiresIn": expiresIn,
                                    @"grantedScopes": [[[token permissions] allObjects] componentsJoinedByString:@","],
                                    @"declinedScopes": [[[token declinedPermissions] allObjects] componentsJoinedByString:@","],
                                    @"signedRequest": @"TODO",
                                    @"userID": userID
                                    };

        return @{
                 @"status": @"connected",
                 @"authResponse": authData
                 };
    } else {
        return @{
                 @"status": @"unknown"
                 };
    }
}

// Some helper functions for categorizing facebook permissions. The javascript
// `login` api is overloaded for initial login and subsequent permission
// requests. Native FB requires initial login to only request read permissions,
// and subsequent permission upgrades require separating read and publish calls

- (BOOL) isPublishPermission:(NSString*)permission {
    return [permission hasPrefix:@"publish"] ||
    [permission hasPrefix:@"manage"] ||
    [permission isEqualToString:@"ads_management"] ||
    [permission isEqualToString:@"create_event"] ||
    [permission isEqualToString:@"rsvp_event"];
}

- (BOOL) areAllPermissionsReadPermissions:(NSArray*)permissions {
    for (NSString *permission in permissions) {
        if ([self isPublishPermission:permission]) {
            return NO;
        }
    }
    return YES;
}

// -----------------------------------------------------------------------------
// GC PLUGIN INTERFACE
// -----------------------------------------------------------------------------

- (void) initializeWithManifest:(NSDictionary *)manifest appDelegate:(TeaLeafAppDelegate *)appDelegate {
    NSLOG(@"{facebook} sending plugin ready event");
    [[PluginManager get] dispatchEvent:@"FacebookPluginReady"
                           forPlugin:self
                           withData:@{@"status": @"OK"}];

    self.tealeafViewController = appDelegate.tealeafViewController;

    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication]
                                    didFinishLaunchingWithOptions:[appDelegate startOptions]];
}

- (void) applicationWillTerminate:(UIApplication *)app {
}

- (void) applicationDidBecomeActive:(UIApplication *)app {
  @try {
    // Track app active event with Facebook app analytics
    [FBSDKAppEvents activateApp];
  }
  @catch (NSException *exception) {
    NSLOG(@"{facebook} Exception while processing active event: %@", exception);
  }
}

- (void) handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
  NSLOG(@"{facebook} handleOpenURL: %@", url);
  @try {
    BOOL isFBCallback = [url.scheme hasPrefix:@"fb"];
    if (isFBCallback) {
        [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication]
                                                       openURL:url
                                             sourceApplication:sourceApplication
                                                    annotation:nil];
    }
  }
  @catch (NSException *exception) {
    NSLOG(@"{facebook} Exception while processing openurl event: %@", exception);
  }
}

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


@end





