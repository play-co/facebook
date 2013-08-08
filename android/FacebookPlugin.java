package com.tealeaf.plugin.plugins;

import android.util.Base64;
import java.security.MessageDigest;
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

public class FacebookPlugin implements IPlugin {
	Context _context;
	Activity _activity;
	SessionTracker _tracker;
	Session _session;

	String _facebookAppID = "";
	String _facebookDisplayName = "";

	//Required for Open Graph Action
	private static final List<String> PERMISSIONS = Arrays.asList("publish_actions");
	private static final String PENDING_PUBLISH_KEY = "pendingPublishReauthorization";
	private boolean pendingPublishReauthorization = false;
	private ProgressDialog progressDialog;
	private WebDialog dialog;
	private Bundle dialogParams = null;
	private String dialogAction = null;

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
	}

	public void onStart() {
		PackageManager manager = _activity.getPackageManager();
		try {
			Bundle meta = manager.getApplicationInfo(_activity.getPackageName(), PackageManager.GET_META_DATA).metaData;
			if (meta != null) {
				_facebookAppID = meta.get("FACEBOOK_APP_ID").toString();
				_facebookDisplayName = meta.get("FACEBOOK_DISPLAY_NAME").toString();
			}

			_tracker = new SessionTracker(_context, new Session.StatusCallback() {
				@Override
				public void call(Session session, SessionState state, Exception exception) {
				}
			}, null, false);
		} catch (Exception e) {
			logger.log("{facebook} Exception on start:", e.getMessage());
		}
	}

	public void openSession(boolean allowLoginUI) {
		_session = _tracker.getSession();

		if (_session == null || _session.getState().isClosed()) {
			_tracker.setSession(null);

			logger.log("{facebook} Building session for App ID =", _facebookAppID);

			Session session = new Session.Builder(_context).setApplicationId(_facebookAppID).build();

			Session.setActiveSession(session);
			_session = session;
		}

		if (!_session.isOpened()) {
			Session.OpenRequest openRequest = new Session.OpenRequest(_activity);

			if (openRequest != null) {
				logger.log("{facebook} Requesting open");

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
						logger.log("{facebook} Session state:", state);

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

	private void showDialogWithoutNotificationBar(String action, Bundle params)
	{
		dialog = new WebDialog.Builder(_activity, Session.getActiveSession(), action, params).
		    setOnCompleteListener(new WebDialog.OnCompleteListener() {
		    @Override
		    public void onComplete(Bundle values, FacebookException error) {
		        if (error != null && !(error instanceof FacebookOperationCanceledException)) {
		            logger.log("{facebook} Error in Sending Requests");
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
	}

	public void sendRequests(String param) {
		Bundle params = new Bundle();
		String message="";

		try {
			JSONObject reqData = new JSONObject(param);

			//The following parameters are required to make the sdk work.
			message = reqData.getString("message");
			if(reqData.has("link")){
				params.putString("link", reqData.getString("link"));
			}
			if(reqData.has("to")){
				params.putString("to", reqData.getString("to"));
			} else if(reqData.has("suggestedFriends")){
				params.putString("suggestions", reqData.getString("suggestedFriends"));
			}
		} catch(JSONException e) {
			logger.log("{facebook} Error in Params of Requests because "+ e.getMessage());
		}
		params.putString("message", message);
	    Session session = Session.getActiveSession();
	    if (session != null) {
	    	showDialogWithoutNotificationBar("apprequests", params);
	    } else {
	    	logger.log("{facebook} User not logged in.");
	    }
	}

	public void login(String json) {
		printHashKey();
		try {
			openSession(true);
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing event:", e.getMessage());
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
			logger.log("{facebook} Exception while processing event:", e.getMessage());
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
			Session session = Session.getActiveSession();

			if (session != null && session.isOpened()) {
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
							logger.log("{facebook} Exception while processing me event callback:", e.getMessage());

							StringWriter writer = new StringWriter();
							PrintWriter printWriter = new PrintWriter( writer );
							e.printStackTrace( printWriter );
							printWriter.flush();
							String stackTrace = writer.toString();
							logger.log("{facebook} (1)Stack: " + stackTrace);

							EventQueue.pushEvent(new MeEvent(e.getMessage()));
						}
					}
				});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new MeEvent("closed"));
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing me event:", e.getMessage());
			EventQueue.pushEvent(new MeEvent(e.getMessage()));
		}
	}

	public void getFriends(String json) {
		try {
			Session session = Session.getActiveSession();

			if (session != null && session.isOpened()) {
				// get Friends
				Request.executeMyFriendsRequestAsync(session, new Request.GraphUserListCallback() {
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
							logger.log("{facebook} Exception while processing friends event callback:", e.getMessage());

							StringWriter writer = new StringWriter();
							PrintWriter printWriter = new PrintWriter( writer );
							e.printStackTrace( printWriter );
							printWriter.flush();
							String stackTrace = writer.toString();
							logger.log("{facebook} (2)Stack: " + stackTrace);

							EventQueue.pushEvent(new FriendsEvent(e.getMessage()));
						}
					}
				});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new FriendsEvent("closed"));
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing friends event:", e.getMessage());
			EventQueue.pushEvent(new FriendsEvent(e.getMessage()));
		}
	}

	public void fql(String query) {
		try {
			String fqlQuery = query;
			Bundle params = new Bundle();
			params.putString("q", fqlQuery);
			Session session = Session.getActiveSession();
			if (session != null && session.isOpened()) {
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
									logger.log("{facebook} Exception while processing fql event callback:", e.getMessage());
									EventQueue.pushEvent(new FqlEvent(e.getMessage(), ""));
								}
							}
						});
				Request.executeBatchAsync(request);
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new FqlEvent("closed", ""));
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing fql event:", e.getMessage());
			EventQueue.pushEvent(new FqlEvent(e.getMessage(), ""));
		}
	}

	public void logout(String json) {
		try {
			Session session = Session.getActiveSession();

			if (session != null) {
				session.closeAndClearTokenInformation();
				Session.setActiveSession(null);
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing event:", e.getMessage());
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
		Session session = Session.getActiveSession();

		if (session != null) {
			session.onActivityResult(_activity, request, result, data);
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

	public void printHashKey() {

        try {
            PackageInfo info = _activity.getApplicationContext().getPackageManager().getPackageInfo("com.hashcube.sudokuquest",
                    PackageManager.GET_SIGNATURES);
            for (Signature signature : info.signatures) {
                MessageDigest md = MessageDigest.getInstance("SHA");
                md.update(signature.toByteArray());
                logger.log("TEMPTAGHASH KEY: ",Base64.encodeToString(md.digest(), Base64.DEFAULT));
            }
        } catch (NameNotFoundException e) {

        } catch (NoSuchAlgorithmException e) {

        }

    }

    public void publishStory(String param) {
	    Bundle params = new Bundle();
	    String actionName = "", app_namespace = "";
	    try {
	    	JSONObject ogData = new JSONObject(param);	
	        Iterator<?> keys = ogData.keys();
	        while( keys.hasNext() ){
	            String key = (String)keys.next();
	    		if(key.equals("app_namespace"))
	    			continue;
	    		if(key.equals("actionName"))
	    			continue;
	    		Object o = ogData.get(key);
	    		if(o is int){
	    			params.putInt(key, (int) o);	
	    		}
	    		else if(o is String){
	    			params.putString(key, (String) o);
	    		}
	    		else if(o is Double){
	    			params.putDouble(key, (Double) o);
	    		}
	    		else if(o is Boolean){
	    			params.putBoolean(key, (Boolean) o);	
	    		}
	    		else{
	    			params.putString(key, (String) o);
	    		}
	        }
	    }
		} catch(JSONException e) {
			logger.log("{facebook} Error in Params of OG because "+ e.getMessage());
		}
	    Request postOGRequest = new Request(Session.getActiveSession(),
	        "me/"+app_namespace+":"+actionName,
	        params,
	        HttpMethod.POST,
	        new Request.Callback() {
	            @Override
	            public void onCompleted(Response response) {
	                FacebookRequestError error = response.getError();
	                if (error != null) {
	                    logger.log("Sending OG Story Failed: " + error.getErrorMessage());
	                } else {
	                    GraphObject graphObject = response.getGraphObject();
	                    String ogActionID = (String)graphObject.getProperty("id");
	                    logger.log("OG Action ID: " + ogActionID);
	                }
	            }
	        });
	    Request.executeBatchAsync(postOGRequest);    	
    }

	public void postStory(String param) {
		// Un-comment the line below to turn on debugging of requests
		//Settings.addLoggingBehavior(LoggingBehavior.REQUESTS);
		String objName="", imgPathName="", url="",title="",urlImageSent="", description="",jsonDataSent="",app_namespace="";
		Boolean image_upload_required = false;

		try {
			JSONObject ogData = new JSONObject(param);

			//The following parameters are required to make the sdk work.
			objName = ogData.getString("objName");
			imgPathName = ogData.getString("imgPathName");
			url = ogData.getString("url");
			title = ogData.getString("title");
			image_upload_required = ogData.getBoolean("image_upload_required");
			urlImageSent = ogData.getString("urlImageSent");
			description = ogData.getString("description");
			jsonDataSent = ogData.getString("jsonDataSent");
			app_namespace = ogData.getString("app_namespace");
		} catch(JSONException e) {
			logger.log("{facebook} Error in Params of OG because "+ e.getMessage());
		}
	    Session session = Session.getActiveSession();
	    if (session != null) {
		    // Check for publish permissions    
		    List<String> permissions = session.getPermissions();
		    if (!isSubsetOf(PERMISSIONS, permissions)) {
		    	pendingPublishReauthorization = true;
		    	Session.NewPermissionsRequest newPermissionsRequest = new Session.NewPermissionsRequest(_activity, PERMISSIONS);
		    	session.requestNewPublishPermissions(newPermissionsRequest);
		    	return;
		    }

		    // Show a progress dialog because the batch request could take a while.
	        progressDialog = ProgressDialog.show(_activity, "","Sharing story, please wait.", true);

		    try {
				// Create a batch request, firstly to post a new object and
				// secondly to publish the action with the new object's id.
				RequestBatch requestBatch = new RequestBatch();

				// Request: Staging image upload request
				// --------------------------------------------

				// If uploading an image, set up the first batch request
				// to do this.
				if (image_upload_required) {
					// Set up image upload request parameters
					Bundle imageParams = new Bundle();
					Bitmap image = BitmapFactory.decodeFile(imgPathName);
					imageParams.putParcelable("file", image);

					// Set up the image upload request callback
				    Request.Callback imageCallback = new Request.Callback() {

						@Override
						public void onCompleted(Response response) {
							// Log any response error
							FacebookRequestError error = response.getError();
							if (error != null) {
								dismissProgressDialog();
								logger.log( error.getErrorMessage());
							}
						}
				    };

				    // Create the request for the image upload
					Request imageRequest = new Request(Session.getActiveSession(), 
							"me/staging_resources", imageParams, 
			                HttpMethod.POST, imageCallback);

					// Set the batch name so you can refer to the result
					// in the follow-on object creation request
					imageRequest.setBatchEntryName("imageUpload");

					// Add the request to the batch
					requestBatch.add(imageRequest);
				}

				// Request: Object request
				// --------------------------------------------

		    	// Set up the JSON representing the ogObj
				JSONObject ogObj = new JSONObject();

				// Set up the ogObj image
				if (image_upload_required) {
					// Set the ogObj's image from the "uri" result from 
					// the previous batch request
					ogObj.put("image", "{result=imageUpload:$.uri}");
				} else {
					// Set the ogObj's image from a URL
					ogObj.put("image", urlImageSent);
				}				
				ogObj.put("title", title);			
				ogObj.put("url",url);
				ogObj.put("description",description);
				JSONObject data = new JSONObject(jsonDataSent);
				ogObj.put("data", data);

				// Set up object request parameters
				Bundle objectParams = new Bundle();
				objectParams.putString("object", ogObj.toString());
				// Set up the object request callback
			    Request.Callback objectCallback = new Request.Callback() {

					@Override
					public void onCompleted(Response response) {
						// Log any response error
						FacebookRequestError error = response.getError();
						if (error != null) {
							dismissProgressDialog();
							logger.log( error.getErrorMessage());
						}
					}
			    };

			    // Create the request for object creation
				Request objectRequest = new Request(Session.getActiveSession(), 
						"me/objects/"+app_namespace+":"+objName, objectParams, 
		                HttpMethod.POST, objectCallback);

				// Set the batch name so you can refer to the result
				// in the follow-on publish action request
				objectRequest.setBatchEntryName("objectCreate");

				// Add the request to the batch
				requestBatch.add(objectRequest);

				// Request: Publish action request
				// --------------------------------------------
				Bundle actionParams = new Bundle();
				// Refer to the "id" in the result from the previous batch request
				actionParams.putString("ogObj", "{result=objectCreate:$.id}");
				// Turn on the explicit share flag
				actionParams.putString("fb:explicitly_shared", "true");

				// Set up the action request callback
				Request.Callback actionCallback = new Request.Callback() {

					@Override
					public void onCompleted(Response response) {
						dismissProgressDialog();
						FacebookRequestError error = response.getError();
						if (error != null) {
							Toast.makeText(_activity
								.getApplicationContext(),
								error.getErrorMessage(),
								Toast.LENGTH_LONG).show();
						} else {
							String actionId = null;
							try {
								JSONObject graphResponse = response
				                .getGraphObject()
				                .getInnerJSONObject();
								actionId = graphResponse.getString("id");
							} catch (JSONException e) {
								logger.log(
										"JSON error "+ e.getMessage());
							}
							Toast.makeText(_activity
								.getApplicationContext(), 
								actionId,
								Toast.LENGTH_LONG).show();
						}
					}
				};

				// Create the publish action request
				Request actionRequest = new Request(Session.getActiveSession(),
						"me/books.reads", actionParams, HttpMethod.POST,
						actionCallback);

				// Add the request to the batch
				requestBatch.add(actionRequest);

				// Execute the batch request
				requestBatch.executeAsync();
			} catch (JSONException e) {
				logger.log(
						"JSON error "+ e.getMessage());
				dismissProgressDialog();
			}
		}
	}	
}
