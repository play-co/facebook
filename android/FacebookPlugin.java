package com.tealeaf.plugin.plugins;

import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import com.tealeaf.logger;
import com.tealeaf.TeaLeaf;
import com.tealeaf.EventQueue;
import com.tealeaf.plugin.IPlugin;
import com.tealeaf.plugin.PluginManager;
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
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.SharedPreferences;
import java.util.HashMap;
import java.util.Map;
import java.util.Iterator;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;
import java.io.StringWriter;
import java.io.PrintWriter;

import android.net.Uri;
import android.view.Window;
import android.view.WindowManager;

import com.facebook.*;
import com.facebook.model.*;
import com.facebook.internal.*;
import com.facebook.widget.*;

import java.util.Set;

public class FacebookPlugin implements IPlugin {
	Context _context;
	Activity _activity;
	SessionTracker _tracker;
	Session _session;

	String _facebookAppID = "";
	String _facebookDisplayName = "";

	private WebDialog dialog;

	public class LoginEvent {
		String state;
		public LoginEvent(String state) {
			this.state = state;
		}
	}
	public class StateEvent {
		String state;

		public StateEvent(String state) {
			this.state = state;
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

	public class MeEvent {
		EventUser user;

		public MeEvent() {
		}

		public MeEvent(EventUser user) {
			this.user = user;
		}
	}

	public class FriendsEvent {
		String error;
		ArrayList<EventUser> friends;

		public FriendsEvent() {
		}

		public FriendsEvent(ArrayList<EventUser> friends) {
			this.friends = friends;
		}
	}

	public class FqlEvent {
		String error;
		String result;

		public FqlEvent(String error, String result) {
			this.result = result;
			this.error = error;
		}
	}

	class InviteFriendsParams {
		String request;
		ArrayList<String> to;

		public InviteFriendsParams(String request, ArrayList<String> to) {
			this.request = request;
			this.to = to;
		}
	}
	public class InviteFriendsEvent {
		InviteFriendsParams response;
		boolean completed;
		public InviteFriendsEvent(String request, ArrayList<String> to, boolean completed) {
			this.completed = completed;
			this.response = new InviteFriendsParams(request, to);
		}
	}

	class PostStoryParams {
		String post_id;

		public PostStoryParams(String post_id) {
			this.post_id = post_id;
		}
	}

	public class PostStoryEvent {
		PostStoryParams response;
		boolean completed;
		
		public PostStoryEvent(String post_id, boolean completed) {
			this.response = new PostStoryParams(post_id);
			this.completed = completed;
		}
	}

	class RequestEvent {
		String id;
		String data;
		String from;
		String message;
		String error;

		public RequestEvent(String id, String from, String data, String message, String error) {
			this.id = id;
			this.from = from;
			this.data = data;
			this.message = message;
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
		Uri intentUri = _activity.getIntent().getData();
		if (intentUri != null) {
			String requestIdParam = intentUri.getQueryParameter("request_ids");
			if (requestIdParam != null) {
				logger.log(requestIdParam);
				String array[] = requestIdParam.split(",");
				String requestId = array[0];
				logger.log("REQUEST ID", requestId);
				getRequestData(requestId);
			}
		}

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

	public void openSession(boolean allowLoginUI, final Integer requestId) {
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
						String stateMessage = state.isClosed() ? "closed" : "open";
						PluginManager.sendEvent("_statusChanged", "FacebookPlugin", new StateEvent(stateMessage)); 
						if (state.isClosed()) {
							if (session != null) {
								session.closeAndClearTokenInformation();
								Session.setActiveSession(null);
							}
						}

						// Print the state to console
						logger.log("{facebook} Session state:", state);
						String errorMessage = null;
						if (exception != null) {
							errorMessage = exception.getMessage();
						}
						PluginManager.sendResponse(new LoginEvent(stateMessage), errorMessage, requestId);
					}
				});
				openRequest.setDefaultAudience(SessionDefaultAudience.FRIENDS);
				openRequest.setPermissions(Arrays.asList("email"));
				openRequest.setLoginBehavior(SessionLoginBehavior.SSO_WITH_FALLBACK);

				_session.openForRead(openRequest);
			}
		} else {
			PluginManager.sendResponse(new LoginEvent("open"), null, requestId);
		}
	}

	public void login(String json, Integer requestId) {
		try {
			openSession(true, requestId);
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing event:", e.getMessage());
		}
	}

	public void isOpen(String json, Integer requestId) {
		try {
			Session session = Session.getActiveSession();

			String openedState = session != null && session.isOpened() ? "open" : "closed";
				PluginManager.sendResponse(new LoginEvent(openedState), null, requestId);
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing event:", e.getMessage());
			PluginManager.sendResponse(new LoginEvent("closed"), e.getMessage(), requestId);
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

	public void getMe(String json, final Integer requestId) {
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
										PluginManager.sendResponse(new MeEvent(), "no data", requestId);
									} else {
										EventUser euser = wrapGraphUser(user);

										PluginManager.sendResponse(new MeEvent(euser), null, requestId);
									}
								} catch (Exception e) {
									logger.log("{facebook} Exception while processing me event callback:", e.getMessage());

									StringWriter writer = new StringWriter();
									PrintWriter printWriter = new PrintWriter( writer );
									e.printStackTrace( printWriter );
									printWriter.flush();
									String stackTrace = writer.toString();
									logger.log("{facebook} (1)Stack: " + stackTrace);

									PluginManager.sendResponse(new MeEvent(), e.getMessage(), requestId);
								}
							}
						});
					}
				});
			} else {
				PluginManager.sendResponse(new MeEvent(), "closed", requestId);
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing me event:", e.getMessage());
			PluginManager.sendResponse(new MeEvent(), e.getMessage(), requestId);
		}
	}

	public void getFriends(String json, final Integer requestId) {
		try {
			final Session session = Session.getActiveSession();

			if (session != null && session.isOpened()) {
				_activity.runOnUiThread(new Runnable() {
					public void run() {
						// get Friends
						Request.executeMyFriendsRequestAsync(session, new Request.GraphUserListCallback() {
							// callback after Graph API response with user objects
							@Override
							public void onCompleted(List users, Response response) {
								try {
									if (users == null) {
										PluginManager.sendResponse(new FriendsEvent(null), "no data", requestId);
									} else {
										ArrayList<EventUser> eusers = new ArrayList<EventUser>();

										for (int ii = 0; ii < users.size(); ++ii) {
											GraphUser user = (GraphUser)users.get(ii);
											if (user != null) {
												EventUser euser = wrapGraphUser(user);
												eusers.add(euser);
											}
										}

									PluginManager.sendResponse(new FriendsEvent(eusers), null, requestId);
									}
								} catch (Exception e) {
									logger.log("{facebook} Exception while processing friends event callback:", e.getMessage());

									StringWriter writer = new StringWriter();
									PrintWriter printWriter = new PrintWriter( writer );
									e.printStackTrace( printWriter );
									printWriter.flush();
									String stackTrace = writer.toString();
									logger.log("{facebook} (2)Stack: " + stackTrace);

									PluginManager.sendResponse(new FriendsEvent(null), e.getMessage(), requestId);
								}
							}
						});
					}
				});
			} else {
				PluginManager.sendResponse(new FriendsEvent(null), "closed", requestId);
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing friends event:", e.getMessage());
			PluginManager.sendResponse(new FriendsEvent(), e.getMessage(), requestId);
		}
	}

	public void fql(final String query, final Integer requestId) {
		try {
			final Session session = Session.getActiveSession();
			if (session != null && session.isOpened()) {
				_activity.runOnUiThread(new Runnable() {
					public void run() {
						String fqlQuery = query;
						Bundle params = new Bundle();
						params.putString("q", fqlQuery);
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
										PluginManager.sendResponse(new FqlEvent("", tempJson.toString()), null, requestId);
									} catch(Exception e) {
										logger.log("{facebook} Exception while processing fql event callback:", e.getMessage());
										PluginManager.sendResponse(new FqlEvent(null, ""), e.getMessage(), requestId);
									}
								}
							});
						Request.executeBatchAsync(request);
					}
				});
			} else {
				PluginManager.sendResponse(new FqlEvent("", ""), "closed", requestId);
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing fql event:", e.getMessage());
			PluginManager.sendResponse(new FqlEvent(null, ""), e.getMessage(), requestId);
		}
	}

	public void logout(String json, Integer requestId) {
		try {
			Session session = Session.getActiveSession();

			if (session != null) {
				session.closeAndClearTokenInformation();
				Session.setActiveSession(null);
			}
		} catch (Exception e) {
			logger.log("{facebook} Exception while processing event:", e.getMessage());
		}
		PluginManager.sendResponse(new StateEvent("closed"), null, requestId);
	}

	public void inviteFriends(String json, final Integer requestId) {
		final Bundle params = new Bundle();
		JSONObject opts = null;
	   try {
		   opts	= new JSONObject(json);
	   } catch (JSONException e) {
			
	   }
	   String message = "";
	   String title = null;
	   if (opts != null) {
			message = opts.optString("message", "");
			title = opts.optString("title");
	   }
		params.putString("message", message);
		params.putString("title", title);
		_activity.runOnUiThread(new Runnable() {
			public void run() {
				try {
					dialog = new WebDialog.Builder(_activity, Session.getActiveSession(), "apprequests", params).
						setOnCompleteListener(new WebDialog.OnCompleteListener() {
							@Override
							public void onComplete(Bundle values, FacebookException error) {
								if (error != null && !(error instanceof FacebookOperationCanceledException)) {
									//not completed
									PluginManager.sendResponse(new InviteFriendsEvent(null, null, false), error.getMessage(), requestId);
								} else {
									String friendRequestId = null;;
									ArrayList<String> recipients = new ArrayList<String>();
									boolean completed = false;
									if (values != null) {
										Set<String> keys = values.keySet();
										for (String s : keys) {
											if (!s.equals("request")) {
												recipients.add(values.getString(s));
											}
										}
										friendRequestId = values.getString("request");
										completed = true;
									}
									PluginManager.sendResponse(new InviteFriendsEvent(friendRequestId, recipients, completed), null, requestId);
								}
								dialog = null;
							}
						}).build();

					Window dialog_window = dialog.getWindow();
					dialog_window.setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN,
							WindowManager.LayoutParams.FLAG_FULLSCREEN);


					dialog.show();
				} catch (Exception e) {
					logger.log("{facebook} Exception while processing event:", e.getMessage());
				}
			}

		});
	}

	public void postStory(final String json, final Integer requestId) {
		_activity.runOnUiThread(new Runnable() {
			public void run() {
				try {
					Bundle params = new Bundle();
					JSONObject opts = new JSONObject(json);
					Iterator i = opts.keys();
					while (i.hasNext()) {
						String k = (String)i.next();
						params.putString(k, opts.getString(k));		
					}

					WebDialog feedDialog = (
						new WebDialog.FeedDialogBuilder(_activity,
							Session.getActiveSession(),
							params))
						.setOnCompleteListener(new WebDialog.OnCompleteListener(){
							@Override
							public void onComplete(Bundle values, FacebookException error) {
								String postID = null;
								boolean completed = false; 
								if (values != null) {
									postID = values.getString("post_id");
									completed = true;
								}
								PluginManager.sendResponse(new PostStoryEvent(postID, completed), null, requestId);
							}	
						})
						.build();
					feedDialog.show();
				} catch (Exception e) {
					logger.log("{facebook} Exception while processing event:", e.getMessage());
				}
			}
		});
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

	private void getRequestData(final String inRequestId) {
		// Create a new request for an HTTP GET with the
		// request ID as the Graph path.
		Request request = new Request(Session.getActiveSession(), 
				inRequestId, null, HttpMethod.GET, new Request.Callback() {

					@Override
					public void onCompleted(Response response) {
						// Process the returned response
						GraphObject graphObject = response.getGraphObject();
						FacebookRequestError error = response.getError();
						String data = ""; 
						String from = "";
						String message = "";
						String errorMessage = "";
						if (error != null) {
								errorMessage = error.getErrorMessage();
								logger.log("{facebook}", "there was an error", errorMessage);
						} else {
							if (graphObject != null) {
								JSONObject receivedData = (JSONObject)graphObject.getProperty("data");
								if (receivedData != null) {
									data = receivedData.toString();
								}
								JSONObject receivedFrom  = (JSONObject)graphObject.getProperty("from");
								if (receivedFrom != null) {
									from = receivedFrom.toString();
								}
								String receivedMessage = (String)graphObject.getProperty("message");
								if (receivedMessage != null ) {
									message = receivedMessage;
								}
							}
						}
						PluginManager.sendEvent("_onRequest", "FacebookPlugin",
								new RequestEvent(inRequestId, from, data, message, errorMessage));
						deleteRequest(inRequestId);
					}
			});
		// Execute the request asynchronously.
		Request.executeBatchAsync(request);
	}

	private void deleteRequest(String inRequestId) {
		// Create a new request for an HTTP delete with the
		// request ID as the Graph path.
		Request request = new Request(Session.getActiveSession(), 
			inRequestId, null, HttpMethod.DELETE, new Request.Callback() {

				@Override
				public void onCompleted(Response response) {
					logger.log("{facebook}", "successfully deleted the request");
					//TODO send an event to javascript
				}
			});
		// Execute the request asynchronously.
		Request.executeBatchAsync(request);
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
}
