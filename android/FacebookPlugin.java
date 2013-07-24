package com.tealeaf.plugin.plugins;

import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import com.tealeaf.logger;
import com.tealeaf.TeaLeaf;
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

import com.facebook.*;
import com.facebook.model.*;

public class FacebookPlugin implements IPlugin {
    Activity _activity;

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
    }

    public void onCreate(Activity activity, Bundle savedInstanceState) {
        this._activity = activity;
    }

    public void onResume() {
    }

    public void onStart() {
        PackageManager manager = _activity.getPackageManager();
        try {
            Bundle meta = manager.getApplicationInfo(_activity.getPackageName(), PackageManager.GET_META_DATA).metaData;
            if (meta != null) {
                _facebookAppID = meta.getString("FACEBOOK_APP_ID");
                _facebookDisplayName = meta.getString("FACEBOOK_DISPLAY_NAME");
            }
        } catch (Exception e) {
            logger.log("{facebook} Exception on start:", e.getMessage());
        }
    }

	public void openSession(boolean allowLoginUI) {
		// start Facebook Login
		Session.openActiveSession(_activity, allowLoginUI, new Session.StatusCallback() {
			// callback when session changes state
			@Override
			public void call(Session session, SessionState state, Exception exception) {
				// If state indicates the session is open,
				if (state.isOpened()) {
					// Notify JS
					EventQueue.pushEvent(new StateEvent("open"));
				} else if (state.isClosed()) {
					EventQueue.pushEvent(new StateEvent("closed"));

					session.closeAndClearTokenInformation();
					Session.setActiveSession(null);
				}

				// Print the state to console
				switch (state) {
					case SessionState.CREATED:
						logger.log("{facebook} Session state: CREATED");
						break;
					case SessionState.CREATED_TOKEN_LOADED:
						logger.log("{facebook} Session state: CREATED_TOKEN_LOADED");
						break;
					case SessionState.OPENING:
						logger.log("{facebook} Session state: OPENING");
						break;
					case SessionState.OPENED:
						logger.log("{facebook} Session state: OPENED");
						break;
					case SessionState.OPENED_TOKEN_UPDATED:
						logger.log("{facebook} Session state: OPEN_TOKEN_UPDATED");
						break;
					case SessionState.CLOSED_LOGIN_FAILED:
						logger.log("{facebook} Session state: CLOSED_LOGIN_FAILED");
						break;
					case SessionState.CLOSED:
						logger.log("{facebook} Session state: CLOSED");
						break;
					default:
						logger.log("{facebook} Unkown session state:", state);
						break;
				}

				if (exception) {
					EventQueue.pushEvent(new ErrorEvent(exception.getMessage()));
				}
			}
		});
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
		EventUser euser = new EventUser;
		euser.id = user.getId();
		euser.photo_url = "http://graph.facebook.com/" + euser.id + "/picture";
		euser.name = user.getName();
		euser.email = user.getEmail();
		euser.first_name = user.getFirstName();
		euser.middle_name = user.getMiddleName();
		euser.last_name = user.getLastName();
		euser.link = user.getLink();
		euser.username = user.getUsername();
		euser.birthday = user.getBirthday();

		// If location is given,
		GraphLocation location = user.getLocation();
		if (location != null) {
			EventLocation elocation = new EventLocation;
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
						if (user == null) {
							EventQueue.pushEvent(new MeEvent("no data"));
						} else {
							EventUser euser = wrapGraphUser(user);
							EventQueue.pushEvent(new MeEvent(euser));
						}
					}
				});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new MeEvent("closed"));
			}
        } catch (Exception e) {
            logger.log("{facebook} Exception while processing event:", e.getMessage());
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
						if (users == null) {
							EventQueue.pushEvent(new FriendsEvent("no data"));
						} else {
							ArrayList<EventUser> eusers= new ArrayList<EventUser>();

							for (Iterator ii = users.iterator(); ii.hasNext(); ii.remove()) {
								GraphUser user = ii.next();
								EventUser euser = wrapGraphUser(user);
								eusers.add(euser);
							}

							EventQueue.pushEvent(new FriendsEvent(eusers));
						}
					}
				});
			} else {
				EventQueue.pushEvent(new StateEvent("closed"));
				EventQueue.pushEvent(new FriendsEvent("closed"));
			}
        } catch (Exception e) {
            logger.log("{facebook} Exception while processing event:", e.getMessage());
        }
    }

    public void logout(String json) {
        try {
			Session session = Session.getActiveSession();

			session.closeAndClearTokenInformation();
			Session.setActiveSession(null);
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

		session.onActivityResult(_activity, request, result, data);
    }

    public boolean consumeOnBackPressed() {
        return true;
    }

    public void onBackPressed() {
    }
}
