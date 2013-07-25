package com.tealeaf.plugin.plugins;

import android.content.pm.PackageInfo;
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
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.SharedPreferences;
import java.util.HashMap;
import java.util.Map;
import java.util.Iterator;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;

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

    public void login(String json) {
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
		euser.photo_url = "http://graph.facebook.com/" + euser.id + "/picture";
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
			elocation.latitude = location.getLatitude();
			elocation.longitude = location.getLongitude();

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
							logger.log("{facebook} Exception while processing event:", e.getMessage());
							EventQueue.pushEvent(new MeEvent(e.getMessage()));
						}
					}
				});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new MeEvent("closed"));
			}
        } catch (Exception e) {
            logger.log("{facebook} Exception while processing event:", e.getMessage());
			EventQueue.pushEvent(new MeEvent(e.getMessage()));
        }
    }

    public void getFriends(String json) {
        try {
			Session session = Session.getActiveSession();

			if (session != null && session.isOpened()) {
				// make request to the /me API
				Request.executeMyFriendsRequestAsync(session, new Request.GraphUserListCallback() {
					// callback after Graph API response with user objects
					@Override
					public void onCompleted(List users, Response response) {
        				try {
							if (users == null) {
								EventQueue.pushEvent(new FriendsEvent("no data"));
							} else {
								ArrayList<EventUser> eusers = new ArrayList<EventUser>();

								for (Iterator ii = users.iterator(); ii.hasNext(); ii.remove()) {
									GraphUser user = (GraphUser)ii.next();
									if (user != null) {
										EventUser euser = wrapGraphUser(user);
										eusers.add(euser);
									}
								}

								EventQueue.pushEvent(new FriendsEvent(eusers));
							}
						} catch (Exception e) {
							logger.log("{facebook} Exception while processing event:", e.getMessage());
							EventQueue.pushEvent(new FriendsEvent(e.getMessage()));
						}
					}
				});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new FriendsEvent("closed"));
			}
        } catch (Exception e) {
            logger.log("{facebook} Exception while processing event:", e.getMessage());
			EventQueue.pushEvent(new FriendsEvent(e.getMessage()));
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
}
