package com.tealeaf.plugin.plugins;

import android.util.Base64;
import java.security.MessageDigest;
import java.lang.Thread;
import android.content.pm.Signature;
import java.security.NoSuchAlgorithmException;
import android.content.pm.PackageInfo;
import java.util.Collection;
import android.graphics.Bitmap;
import com.facebook.FacebookRequestError;
import com.facebook.widget.WebDialog;
import android.app.ProgressDialog;
import android.widget.Toast;
import android.graphics.BitmapFactory;
import android.R;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import com.tealeaf.logger;
import com.tealeaf.TeaLeaf;
import com.tealeaf.EventQueue;
import com.tealeaf.plugin.IPlugin;
import java.io.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import com.tealeaf.util.HTTP;
import java.net.URI;
import android.app.Activity;
import android.content.Intent;
import android.content.Context;
import android.util.Log;
import android.os.Bundle;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import com.facebook.RequestBatch;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.SharedPreferences;
import android.view.WindowManager;
import android.view.Window;
import java.util.HashMap;
import java.util.Map;
import java.util.Iterator;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;
import java.io.StringWriter;
import java.io.PrintWriter;

import com.facebook.*;
import com.facebook.model.*;
import com.facebook.internal.*;
import com.facebook.Session.*;

public class FacebookPlugin implements IPlugin {
	Context _context;
	Activity _activity;
	SessionTracker _tracker;
	Session _session;

	// Pulled from the games manifest.json file
	String _facebookAppID       = "";
	String _facebookDisplayName = "";
	String _facebookNamespace   = "";

	//Required for Open Graph Action
	private static final List<String> PERMISSIONS = Arrays.asList("publish_actions");
	private static final int REAUTH_ACTIVITY_CODE = 100;
	private ProgressDialog progressDialog;
	private WebDialog dialog;
	private Bundle dialogParams = null;
	private String dialogAction = null;
	private String requestPublishPermissionsCallbackParam = null;

	public class StateEvent extends com.tealeaf.event.Event {
		String state;

		public StateEvent(String state) {
			super("facebookState");
			this.state = state;
		}
	}

	public class ErrorEvent extends com.tealeaf.event.Event {
		String description;

		public ErrorEvent(String description) {
			super("facebookError");
			this.description = description;
		}
	}

	public class EventLocation {
		public String street, city, state, country, zip;
		public double latitude, longitude;
	}

	public class EventUser {
		public String id, photo_url, name, email;
		public String first_name, middle_name, last_name;
		public String link, username, birthday;
		EventLocation location;
	}

	public class MeEvent extends com.tealeaf.event.Event {
		String error;
		EventUser user;

		public MeEvent(String error) {
			super("facebookMe");
			this.error = error;
		}

		public MeEvent(EventUser user) {
			super("facebookMe");
			this.user = user;
		}
	}

	public class RequestEvent extends com.tealeaf.event.Event {
		String error;
		Bundle response;

		public RequestEvent(String error) {
			super("facebookRequest");
			this.error = error;
		}

		public RequestEvent(Bundle response) {
			super("facebookRequest");
			this.response = response;
		}
	}

	public class FriendsEvent extends com.tealeaf.event.Event {
		String error;
		ArrayList<EventUser> friends;

		public FriendsEvent(String error) {
			super("facebookFriends");
			this.error = error;
		}

		public FriendsEvent(ArrayList<EventUser> friends) {
			super("facebookFriends");
			this.friends = friends;
		}
	}

	public class newCATPIEvent extends com.tealeaf.event.Event {
		String error;
		String result;

		public newCATPIEvent(String error, String result) {
			super("facebooknewCATPI");
			this.result = result;
			this.error = error;
		}
	}

	public class OgEvent extends com.tealeaf.event.Event {
		String error;
		String result;

		public OgEvent(String error, String result) {
			super("facebookOg");
			this.result = result;
			this.error = error;
		}
	}

	public class FqlEvent extends com.tealeaf.event.Event {
		String error;
		String result;

		public FqlEvent(String error, String result) {
			super("facebookFql");
			this.result = result;
			this.error = error;
		}
	}

	public FacebookPlugin() {
	}

	public void onCreateApplication(Context applicationContext) {
		_context = applicationContext;
	}

	public void onCreate(Activity activity, Bundle savedInstanceState) {
		_activity = activity;
	}

	public void onResume() {
		// Track app active events
		com.facebook.AppEventsLogger.activateApp(_context, _facebookAppID);
	}

	public void onStart() {
		PackageManager manager = _activity.getPackageManager();
		try {
			Bundle meta = manager.getApplicationInfo(_activity.getPackageName(), PackageManager.GET_META_DATA).metaData;
			if (meta != null) {
				_facebookAppID       = meta.get("FACEBOOK_APP_ID").toString();
				_facebookDisplayName = meta.get("FACEBOOK_DISPLAY_NAME").toString();
				_facebookNamespace   = meta.get("FACEBOOK_NAMESPACE").toString();
			}

			_tracker = new SessionTracker(_context, new Session.StatusCallback() {
				@Override
				public void call(Session session, SessionState state, Exception exception) {
				}
			}, null, false);
		} catch (Exception e) {
			logger.log("{facebook-native} Exception on start:", e.getMessage());
		}
	}

	public void sendAppEventPurchased(String param){
		try {
			JSONObject ogData = new JSONObject(param);	
	        AppEventsLogger loggerF = AppEventsLogger.newLogger(_activity);
			Bundle parameters = new Bundle();
			parameters.putString(AppEventsConstants.EVENT_PARAM_CURRENCY, "USD");
			parameters.putString(AppEventsConstants.EVENT_PARAM_CONTENT_TYPE, (String) ogData.get("currency"));
			parameters.putString(AppEventsConstants.EVENT_PARAM_CONTENT_ID, (String) ogData.get("content"));
			loggerF.logEvent(AppEventsConstants.EVENT_NAME_PURCHASED,
					        (Double) ogData.get("price"),
					        parameters);
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing purchased_send_fb event:", e.getMessage());
			EventQueue.pushEvent(new MeEvent(e.getMessage()));
		}
	}

	public void sendAppEventAchievement(String param){
		try {
			JSONObject ogData = new JSONObject(param);	
	        AppEventsLogger loggerF = AppEventsLogger.newLogger(_activity);
			Bundle parameters = new Bundle();
			parameters.putString(AppEventsConstants.EVENT_PARAM_DESCRIPTION, (String) ogData.get("name"));
			parameters.putString(AppEventsConstants.EVENT_PARAM_NUM_ITEMS, Integer.toString((Integer) ogData.get("max_ms")));
			loggerF.logEvent(AppEventsConstants.EVENT_NAME_UNLOCKED_ACHIEVEMENT,
					        parameters);
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing achievement_send_fb event:", e.getMessage());
			EventQueue.pushEvent(new MeEvent(e.getMessage()));
		}
	}

	public void openSession(boolean allowLoginUI) {
		_session = _tracker.getSession();

		if (_session == null || _session.getState().isClosed()) {
			_tracker.setSession(null);

			logger.log("{facebook-native} Building session for App ID =", _facebookAppID);

			Session session = new Session.Builder(_context).setApplicationId(_facebookAppID).build();

			Session.setActiveSession(session);
			_session = session;
		}

		if (!_session.isOpened()) {
			Session.OpenRequest openRequest = new Session.OpenRequest(_activity);

			if (openRequest != null) {
				logger.log("{facebook-native} Requesting open");

				openRequest.setCallback( new Session.StatusCallback() {
					@Override
					public void call(Session session, SessionState state, Exception exception) {
						// If state indicates the session is open,
						if (state.isOpened()) {
							// Notify JS
							EventQueue.pushEvent(new StateEvent("open"));
						} else if (state.isClosed()) {
							EventQueue.pushEvent(new StateEvent("closed"));

							if (session != null) {
								session.closeAndClearTokenInformation();
								Session.setActiveSession(null);
							}
						}

						// Print the state to console
						logger.log("{facebook-native} Session state:", state);

						if (exception != null) {
							EventQueue.pushEvent(new ErrorEvent(exception.getMessage()));
						}
					}
				});
				openRequest.setDefaultAudience(SessionDefaultAudience.FRIENDS);
				openRequest.setPermissions(Arrays.asList("email"));
				openRequest.setLoginBehavior(SessionLoginBehavior.SSO_WITH_FALLBACK);

				_session.openForRead(openRequest);
			}
		}
	}

	private void showDialogWithoutNotificationBar(final Session session, final String action,final Bundle params)
	{
        _activity.runOnUiThread(new Runnable() {
        public void run() {
            dialog = new WebDialog.Builder(_activity, session, action, params).
            //dialog = new WebDialog.RequestsDialogBuilder(_activity, session, params).
                setOnCompleteListener(new WebDialog.OnCompleteListener() {
                    @Override
                    public void onComplete(Bundle values, FacebookException error) {
                        if (error != null && !(error instanceof FacebookOperationCanceledException)) {
                            logger.log("{facebook-native} Error in Sending Requests");
                            EventQueue.pushEvent(new RequestEvent("error"));
                        } else {
                            EventQueue.pushEvent(new RequestEvent(values));
                        }
                        dialog = null;
                        dialogAction = null;
                        dialogParams = null;
                    }
                }).build();
            Window dialog_window = dialog.getWindow();
            dialog_window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
                WindowManager.LayoutParams.FLAG_FULLSCREEN);

            dialogAction = action;
            dialogParams = params;

            dialog.show();
        }});
	}

	public void sendRequests(String param) {
		Bundle params = new Bundle();
		String message="";

		try {
			JSONObject reqData = new JSONObject(param);
			message = reqData.getString("message");
            params.putString("message", message);

            if(reqData.has("title")){
                params.putString("title", reqData.getString("title"));
            }
            if(reqData.has("to")){
                params.putString("to", reqData.getString("to"));
            } else if(reqData.has("suggestedFriends")){
                params.putString("suggestions", reqData.getString("suggestedFriends"));
            }
		} catch(JSONException e) {
			logger.log("{facebook-native} Error in Params of Requests because "+ e.getMessage());
		}

	    Session session = Session.getActiveSession();
        if(session==null)
        {
            logger.log("{facebook-native} Trying to open Session from Cache");
            session = session.openActiveSessionFromCache(_activity.getApplicationContext());
        }
	    if (session != null) {
	    	showDialogWithoutNotificationBar(session, "apprequests", params);
	    } else {
	    	logger.log("{facebook-native} User not logged in.");
	    }
	}

	public void login(String json) {
		printHashKey();
		try {
			openSession(true);
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing event:", e.getMessage());
		}
	}

	public void isOpen(String json) {
		try {
			Session session = Session.getActiveSession();

			if (session != null && session.isOpened()) {
				EventQueue.pushEvent(new StateEvent("open"));
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
			}
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing event:", e.getMessage());
		}
	}

	private EventUser wrapGraphUser(GraphUser user) {
		Object email = user.asMap().get("email");

		EventUser euser = new EventUser();
		euser.id = user.getId();
		euser.photo_url = (euser.id != null) ? ( "http://graph.facebook.com/" + euser.id + "/picture" ) : "";
		euser.name = user.getName();
		euser.email = (email != null) ? email.toString() : "";
		euser.first_name = user.getFirstName();
		euser.middle_name = user.getMiddleName();
		euser.last_name = user.getLastName();
		euser.link = user.getLink();
		euser.username = user.getUsername();
		euser.birthday = user.getBirthday();

		// If location is given,
		GraphLocation location = user.getLocation();
		if (location != null) {
			EventLocation elocation = new EventLocation();
			elocation.city = location.getCity();
			elocation.street = location.getStreet();
			elocation.state = location.getState();
			elocation.country = location.getCountry();
			elocation.zip = location.getZip();
			elocation.latitude = (location.asMap().get("latitude") != null) ? location.getLatitude() : 0;
			elocation.longitude = (location.asMap().get("longitude") != null) ? location.getLongitude() : 0;

			euser.location = elocation;
		}

		return euser;
	}

	public void getMe(String json) {
		try {
			final Session session = Session.getActiveSession();

			if (session != null && session.isOpened()) {
				_activity.runOnUiThread(new Runnable() {
        		public void run() {
					// make request to the /me API
					Request.executeMeRequestAsync(session, new Request.GraphUserCallback() {
						// callback after Graph API response with user object
						@Override
						public void onCompleted(GraphUser user, Response response) {
							try {
								if (user == null) {
									EventQueue.pushEvent(new MeEvent("no data"));
								} else {
									EventUser euser = wrapGraphUser(user);

									EventQueue.pushEvent(new MeEvent(euser));
								}
							} catch (Exception e) {
								logger.log("{facebook-native} Exception while processing me event callback:", e.getMessage());

								StringWriter writer = new StringWriter();
								PrintWriter printWriter = new PrintWriter( writer );
								e.printStackTrace( printWriter );
								printWriter.flush();
								String stackTrace = writer.toString();
								logger.log("{facebook-native} (1)Stack: " + stackTrace);

								EventQueue.pushEvent(new MeEvent(e.getMessage()));
							}
						}
					});
			    }
    		});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new MeEvent("closed"));
			}
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing me event:", e.getMessage());
			EventQueue.pushEvent(new MeEvent(e.getMessage()));
		}
	}

	public void getFriends(String json) {
		try {
			Session session = Session.getActiveSession();

			if(session==null)
			{
				logger.log("{facebook-native} Trying to open Session from Cache");
				session = session.openActiveSessionFromCache(_activity.getApplicationContext());
			}
            final Session finalSession = session;
			if (session != null && session.isOpened()) {
				// get Friends
				_activity.runOnUiThread(new Runnable() {
        		public void run() {
                    Request.executeMyFriendsRequestAsync(finalSession, new Request.GraphUserListCallback() {
                        // callback after Graph API response with user objects
                        @Override
                        public void onCompleted(List users, Response response) {
                            try {
                                if (users == null) {
                                    EventQueue.pushEvent(new FriendsEvent("no data"));
                                } else {
                                    ArrayList<EventUser> eusers = new ArrayList<EventUser>();

                                    for (int ii = 0; ii < users.size(); ++ii) {
                                        GraphUser user = (GraphUser)users.get(ii);
                                        if (user != null) {
                                            EventUser euser = wrapGraphUser(user);
                                            eusers.add(euser);
                                        }
                                    }

                                    EventQueue.pushEvent(new FriendsEvent(eusers));
                                }
                            } catch (Exception e) {
                                logger.log("{facebook-native} Exception while processing friends event callback:", e.getMessage());

                                StringWriter writer = new StringWriter();
                                PrintWriter printWriter = new PrintWriter( writer );
                                e.printStackTrace( printWriter );
                                printWriter.flush();
                                String stackTrace = writer.toString();
                                logger.log("{facebook-native} (2)Stack: " + stackTrace);

                                EventQueue.pushEvent(new FriendsEvent(e.getMessage()));
                            }
                        }
                    });
                }});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new FriendsEvent("closed"));
			}
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing friends event:", e.getMessage());
			EventQueue.pushEvent(new FriendsEvent(e.getMessage()));
		}
	}

	public void fql(String query) {
		try {
			String fqlQuery = query;
			final Bundle params = new Bundle();
			params.putString("q", fqlQuery);
			final Session session = Session.getActiveSession();
			if (session != null && session.isOpened()) {
				_activity.runOnUiThread(new Runnable() {
	        		public void run() {
						Request request = new Request(session,
								"/fql",
								params,
								HttpMethod.GET,
								new Request.Callback() {
									public void onCompleted(Response response) {
										try {
											JSONArray tempObj = (JSONArray)response.getGraphObject().getProperty("data");
											JSONObject temp = (JSONObject)tempObj.get(0);
											JSONArray tempJson = (JSONArray)temp.getJSONArray("fql_result_set");
											EventQueue.pushEvent(new FqlEvent("", tempJson.toString()));
										} catch(Exception e) {
											logger.log("{facebook-native} Exception while processing fql event callback:", e.getMessage());
											EventQueue.pushEvent(new FqlEvent(e.getMessage(), ""));
										}
									}
								});
						Request.executeBatchAsync(request);
					}
				});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new FqlEvent("closed", ""));
			}
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing fql event:", e.getMessage());
			EventQueue.pushEvent(new FqlEvent(e.getMessage(), ""));
		}
	}

	public void logout(String json) {
		try {
			Session session = Session.getActiveSession();
			if(session==null)
			{
				logger.log("{facebook-native} Trying to open Session from Cache");
				session = session.openActiveSessionFromCache(_activity.getApplicationContext());
			}
			logger.log("{facebook-native} SESSION INFO: "+session+":OL");
			if (session != null) {
				session.closeAndClearTokenInformation();
				logger.log("{facebook-native} SESSION INFO: "+session+":OL");
				Session.setActiveSession(null);
			}
		} catch (Exception e) {
			logger.log("{facebook-native} Exception while processing event:", e.getMessage());
		}
	}

	public void onPause() {
	}

	public void onStop() {
	}

	public void onDestroy() {
	}

	public void onNewIntent(Intent intent) {
	}

	public void setInstallReferrer(String referrer) {
	}

	public void onActivityResult(Integer request, Integer result, Intent data) {
		logger.log("{facebook-native} - onActivityResult");
		Session session = Session.getActiveSession();

		if (session != null) {
			session.onActivityResult(_activity, request, result, data);
		}

		// The current SDK (3.5.x) has a bug whereby the NewPermissionsRequest callback isn't triggered:
		//    https://developers.facebook.com/docs/android/change-log-3.x#ver3_6_0
		// My attempts at updating the SDK to a newer version caused me all sorts of trouble, so this is my hack "David @oodavid King"
		if(requestPublishPermissionsCallbackParam != null){
			publishStory2(requestPublishPermissionsCallbackParam, false);
		}
	}

	public boolean consumeOnBackPressed() {
		return true;
	}

	public void onBackPressed() {
	}

	private boolean isSubsetOf(Collection<String> subset, Collection<String> superset) {
	    for (String string : subset) {
	        if (!superset.contains(string)) {
	            return false;
	        }
	    }
	    return true;
	}

	private void dismissProgressDialog() {
		// Dismiss the progress dialog
		if (progressDialog != null) {
            progressDialog.dismiss();
            progressDialog = null;
        }
	}

	public void logError(String errorDesc) {
		logger.log("{facebook-native} logError "+ errorDesc);
	}

	public void printHashKey() {

        try {
            PackageInfo info = _activity.getApplicationContext().getPackageManager().getPackageInfo("com.hashcube.sudokuquest",
                    PackageManager.GET_SIGNATURES);
            for (Signature signature : info.signatures) {
                MessageDigest md = MessageDigest.getInstance("SHA");
                md.update(signature.toByteArray());
                logger.log("{facebook-native} TEMPTAGHASH KEY: ",Base64.encodeToString(md.digest(), Base64.DEFAULT));
            }
        } catch (NameNotFoundException e) {

        } catch (NoSuchAlgorithmException e) {

        }

    }

	public void newCATPIR(String dummyParam) {
		Thread catpiThread = new Thread(){
			public void run(){
				logger.log("{facebook-native} Inside newCATPIR");
				Request newCATPIRequest = Request.newCustomAudienceThirdPartyIdRequest(
				  null,  // Session
				  _context,  // Context
				  new Request.Callback() {
				    @Override
				    public void onCompleted(Response response) {
				    	try{
						    String app_user_id = null;
						    GraphObject graphObject = response.getGraphObject();
						    if (graphObject != null) {
						        app_user_id = (String)graphObject.getProperty("custom_audience_third_party_id");
						        EventQueue.pushEvent(new newCATPIEvent("", app_user_id));
						        logger.log("{facebook-native} {facebook} The CATPI is "+ app_user_id);
						    }
						    else {
		  				        EventQueue.pushEvent(new newCATPIEvent("ERROR", ""));
						    }
				  		} catch(Exception e) {
				  			logError(e.toString());
				  		}
				    }
				  }
				);
				logger.log("{facebook-native} Defn Fine of CATPI");
				newCATPIRequest.executeAndWait();
				logger.log("{facebook-native} Calling Fine of CATPI");
			}
		};
		catpiThread.start();
	}

	/** PUBLISH (Open Graph) STORY
	 *
	 *		Publishes a story if possible.
	 *
	 *			publishStory                accepts one parameter and simply calls publishStory2
	 *			publishStory2               has an EXTRA parameter to denote whether we can request 'publish_actions' permissions if we don't have them
	 *			requestPublishPermissions   requests permissions from facebook, then calls publishStory2 when done (it sets the flag to FALSE to say that we shouldn't request permissions again)
	 *
	 *		Notes
	 *
	 *			There is a bug in the Facebook SDK prior to 3.6 whereby the NewPermissionsRequest callback isn't triggered.
	 *			My (crude) fix is to modify onActivityResult to deal with this edge case.
	 *			See my comments on requestPublishPermissions and onActivityResult
	 *
	 * @author		David "oodavid" King
	 */
	public void publishStory(String param) {
		logger.log("{facebook-native} publishStory");
		// Publish the story, allowing the permissions to be requestd if needed
		publishStory2(param, true);
	}
	private void requestPublishPermissions(Session session, final String param) {
		logger.log("{facebook-native} Requesting for new Publish Permissions");
		if (session != null) {
			// Request the permissons
			Session.NewPermissionsRequest newPermissionsRequest =
				new Session.NewPermissionsRequest(_activity, PERMISSIONS)
					.setRequestCode(REAUTH_ACTIVITY_CODE);
			// Store the params to be used by onActivityResult to fix a dirty hack (see onActivityResult for more info)
			requestPublishPermissionsCallbackParam = param;
			/* We SHOULD use a callback like below to trigger the second attempt at the publishStory
			newPermissionsRequest.setCallback(new Session.StatusCallback() {
					@Override
					public void call(Session session, SessionState state, Exception exception) {
						publishStory2(param, false);
				});
			*/
			session.requestNewPublishPermissions(newPermissionsRequest);
		}
	}
	public void publishStory2(String param, Boolean bRequestPermissions) {
		logger.log("{facebook-native} publishStory2");
		// Before we attempt to publish the story, make sure we have a session
		Session session = Session.getActiveSession();
		if(session==null){
			logger.log("{facebook-native} Trying to open Session from Cache");
			session = session.openActiveSessionFromCache(_activity.getApplicationContext());
		}
		if(session == null || !session.isOpened()){
			EventQueue.pushEvent(new OgEvent("Not Logged In", ""));
			return;
		}
		// Does the session have the required publish permissions?
		List<String> permissions = session.getPermissions();
		if(!permissions.containsAll(PERMISSIONS)){
			// Request for permissions - the 'bRequestPermissions' flag prevents this looping indefinitely
			if(bRequestPermissions){
				requestPublishPermissions(session, param);
				return;
			}
			// Looks like we've already requested permissions before, we must assume the user pressed "Not Now" (or some other eventuality)
			EventQueue.pushEvent(new OgEvent("Rejected", ""));
			return;
		}
		// We pull this from the params passed to us from javascript (see below)
		String actionType = null;
		// Convert the params from javascript into a data bundle to post to Facebook
		final Bundle params = new Bundle();
		try {
			JSONObject ogData = new JSONObject(param);
			Iterator<?> keys  = ogData.keys();
			while(keys.hasNext()){
				String key = (String)keys.next();
				Object o   = ogData.get(key);
				// Special case - we MUST have the actionType as a parameter
				if(key.equals("actionType")){
					actionType = (String) o;
					continue;
				}
				// Otherwise, just add to our bundle
				params.putString(key, (String) o);
			}
		} catch(JSONException e) {
			logger.log("{facebook-native} Error in Params of OG because "+ e.getMessage());
		}
		// Validate - do we have the required actionType?
		if(actionType == null){
			EventQueue.pushEvent(new OgEvent("Required 'actionType' property not set", ""));
			return;
		}
		final String fActionType = actionType;
		// We should have everything ready to post to facebook
		// logger.log("{facebook-native} Parsed properly with namespace="+namespace+" and actionType="+fActionType);
		_activity.runOnUiThread(new Runnable() {
			public void run() {
				Request postOGRequest = new Request(Session.getActiveSession(),
					"me/"+_facebookNamespace+":"+fActionType,
					params,
					HttpMethod.POST,
					new Request.Callback() {
						@Override
						public void onCompleted(Response response) {
							FacebookRequestError error = response.getError();
							if (error != null) {
								logger.log("{facebook-native} Sending OG Story Failed: " + error.getErrorMessage());
								EventQueue.pushEvent(new OgEvent(error.getErrorMessage(), ""));
							} else {
								GraphObject graphObject = response.getGraphObject();
								String ogActionID = (String)graphObject.getProperty("id");
								logger.log("{facebook-native} OG Action ID: " + ogActionID);
								EventQueue.pushEvent(new OgEvent("", ogActionID));
							}
						}
					});
				Request.executeBatchAsync(postOGRequest);
			}
		});
	}

}
