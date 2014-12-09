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
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;
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
import java.util.HashSet;
import java.util.Map;
import java.util.Iterator;
import java.util.ArrayList;
import java.util.List;
import java.util.Arrays;
import java.util.Date;
import java.io.StringWriter;
import java.io.PrintWriter;

import android.net.Uri;
import android.view.Window;
import android.view.WindowManager;

import com.facebook.*;
import com.facebook.model.*;
import com.facebook.internal.*;
import com.facebook.widget.*;

import com.facebook.AppEventsLogger;
import com.facebook.FacebookDialogException;
import com.facebook.FacebookException;
import com.facebook.FacebookOperationCanceledException;
import com.facebook.FacebookAuthorizationException;
import com.facebook.FacebookRequestError;
import com.facebook.FacebookServiceException;
import com.facebook.Request;
import com.facebook.Request.GraphUserCallback;
import com.facebook.Response;
import com.facebook.Session;
import com.facebook.Session.OpenRequest;
import com.facebook.SessionState;
import com.facebook.UiLifecycleHelper;
import com.facebook.model.GraphObject;
import com.facebook.model.GraphUser;
import com.facebook.widget.FacebookDialog;
import com.facebook.widget.WebDialog;
import com.facebook.widget.WebDialog.OnCompleteListener;

import java.util.Set;

public class FacebookPlugin implements IPlugin {
  Context _context;
  private Activity _activity;
  SessionTracker _tracker;

  Integer activeRequest = null;

  String _facebookAppID = "";
  String _facebookDisplayName = "";

  private String appID = null;
  private String userID = null;

  void onJSONException (JSONException e) {
    logger.log("{facebook} JSONException:", e.getMessage());
  }

  // ---------------------------------------------------------------------------
  // JavaScript interface
  // ---------------------------------------------------------------------------

  public void facebookInit (String s_json) {
    logger.log("{facebook} init");

    JSONObject res;
    try {
      res = new JSONObject(s_json);
    } catch (JSONException e) {
      onJSONException(e);
      return;
    }

    logger.log("\t", res);

    appID = res.optString("appId", "");

    Session session = new Session.Builder(_activity)
      .setApplicationId(appID)
      .build();

    // Automatically send open request if we have a cached session
    if (session.getState() == SessionState.CREATED_TOKEN_LOADED) {
      Session.setActiveSession(session);
      Session.OpenRequest openRequest = new Session.OpenRequest(_activity);
      openRequest.setCallback(new Session.StatusCallback() {
        @Override
        public void call(Session session, SessionState state, Exception exception) {
          onSessionStateChange(state, exception);
        }
      });
    }

    // Emit login event if session is active.
    if (checkActiveSession(session)) {
      onSessionStateChange(session.getState(), null);
    }
  }

  public void getLoginStatus(String s_opts, Integer requestId) {
    logger.log("{facebook} getLoginStatus");
    sendResponse(getResponse(), null, requestId);
  }

  public void getAuthResponse(String s_opts, Integer requestId) {
    logger.log("{facebook} getAuthResponse");
    JSONObject authResponse = getResponse();
    JSONObject response = new JSONObject();
    try {
      response.put("authResponse", authResponse);
    } catch (JSONException e) {
      // What could possibly cause this to throw an error?
    }

    sendResponse(response, null, requestId);
  }

  public void login(String s_opts, Integer requestId) {
    activeRequest = requestId;

    logger.log("{facebook} login");
    String errorMessage;
    JSONObject opts;
    try {
      opts = new JSONObject(s_opts);
    } catch (JSONException e) {
      onJSONException(e);
      sendResponse(getErrorResponse("error parsing json opts"), requestId);
      return;
    }

    String scopes = opts.optString("scope", "");

    // Get the permissions
    String[] arrayPermissions = scopes.split(",");

    List<String> permissions = null;
    if (arrayPermissions.length > 0) {
      permissions = Arrays.asList(arrayPermissions);
    }

    // Get the currently active session
    Session session = Session.getActiveSession();

    // Check if the active session is open
    if (checkActiveSession(session)) {
      // Reauthorize flow
      boolean publishPermissions = false;
      boolean readPermissions = false;

      // Figure out if this will be a read or publish reauthorize
      if (permissions == null) {
        // No permissions, read
        readPermissions = true;
      }

      // Loop through the permissions to see what is being requested
      for (String permission : arrayPermissions) {
        if (isPublishPermission(permission)) {
          publishPermissions = true;
        } else {
          readPermissions = true;
        }
        // Break if we have a mixed bag, as this is an error
        if (publishPermissions && readPermissions) {
          break;
        }
      }

      if (publishPermissions && readPermissions) {
        try {
          JSONObject err = new JSONObject();
          err.put("error", "Cannot ask for both read and publish permissions.");
          sendResponse(err, null, requestId);
        } catch (JSONException e) {
          onJSONException(e);
        }
        activeRequest = null;
        return;
      } else {
        // Set up the new permissions request
        Session.NewPermissionsRequest newPermissionsRequest =
          new Session.NewPermissionsRequest(_activity, permissions);

        // Check for write permissions, the default is read (empty)
        if (publishPermissions) {
          // Request new publish permissions
          session.requestNewPublishPermissions(newPermissionsRequest);
        } else {
          // Request new read permissions
          session.requestNewReadPermissions(newPermissionsRequest);
        }
      }
    } else {
      // Initial login
      session = new Session.Builder(_activity)
        .setApplicationId(appID)
        .build();

      Session.setActiveSession(session);
      Session.OpenRequest openRequest = new Session.OpenRequest(_activity);
      openRequest.setPermissions(permissions);
      openRequest.setCallback(new Session.StatusCallback() {
        @Override
        public void call(Session session, SessionState state, Exception exception) {
          onSessionStateChange(state, exception);
        }
      });

      // Can only ask for read permissions initially
      session.openForRead(openRequest);
    }
  }

  public void api (String s_json, Integer _requestId) {

    final Integer requestId = _requestId;
    log("api");

    JSONObject opts;
    JSONObject _params;
    String _method;
    String path;

    try {
      opts = new JSONObject(s_json);
      _params = opts.getJSONObject("params");
      _method = opts.optString("method", "get");
      path = opts.getString("path");
    } catch (JSONException e) {
      onJSONException(e);
      sendResponse(getErrorResponse("error parsing JSON opts"), requestId);
      return;
    }

    Bundle params = null;
    if (_params.length() > 0) {
      try {
        params = BundleJSONConverter.convertToBundle(_params);
      } catch (JSONException e) {
        log("api - error converting JSONObject to Bundle");
      }
    }

    HttpMethod method;
    if (_method.equals("post")) {
      method = HttpMethod.POST;
    } else if (_method.equals("delete")) {
      method = HttpMethod.DELETE;
    } else {
      method = HttpMethod.GET;
    }

    Session session = Session.getActiveSession();

    if (path.charAt(0) == '/') {
      path = (new StringBuilder(path)).deleteCharAt(0).toString();
    }

    Request req = new Request(session, path, params, method, new Request.Callback() {
      @Override
      public void onCompleted(Response res) {
        if (res.getError() != null) {
          sendResponse(getFacebookRequestError(res.getError()), null, requestId);
        } else {
          sendResponse(res.getRawResponse(), null, requestId);
        }
      }
    });

    req.executeAndWait();
  }

  public void ui(String s_json, Integer requestId) {
    log("ui");
    final Integer _requestId = requestId;
    Session session = Session.getActiveSession();

    JSONObject json = null;
    Bundle params = null;

    // Parse JSON;
    try {
      json = new JSONObject(s_json);
    } catch (JSONException e) {
      onJSONException(e);
      log("ui failed to parse JSON blob");
      sendResponse(getErrorResponse("failed to parse JSON"), null, requestId);
      return;
    }

    if (json.length() > 0) {
      // get json bundle
      try {
        params = BundleJSONConverter.convertToBundle(json);
      } catch (JSONException e) {
        onJSONException(e);
        sendResponse(
          getErrorResponse("error converting JSONObject to bundle"),
          null,
          _requestId
        );
        return;
      }
    }

    final String method = params.getString("method");
    if (method == null) {
      sendResponse(getErrorResponse("method param is required"), null, requestId);
      return;
    }

    params.remove("method");
    final Bundle dialogParams = params;

    // Setup callback context
    final OnCompleteListener dialogCallback = new OnCompleteListener() {
      @Override
      public void onComplete(Bundle values, FacebookException exception) {
        if (exception != null) {
          handleError(exception, _requestId);
        } else {
          try {
            JSONObject res = BundleJSONConverter.convertToJSON(values);
            sendResponse(res, null, _requestId);
          } catch (JSONException e) {
            sendResponse(
              getErrorResponse(exception.getMessage()), null, _requestId
            );
          }
        }
      }
    };

    final Activity devkitActivity = _activity;
    if (method.equalsIgnoreCase("feed")) {
      Runnable runnable = new Runnable() {
        public void run() {
          WebDialog feedDialog = (new WebDialog.FeedDialogBuilder(
            devkitActivity,
            Session.getActiveSession(),
            dialogParams)
          ).setOnCompleteListener(dialogCallback).build();

          feedDialog.show();
        }
      };
      devkitActivity.runOnUiThread(runnable);
    } else if (method.equalsIgnoreCase("apprequests")) {
      Runnable runnable = new Runnable() {
        public void run() {
          WebDialog requestsDialog = (new WebDialog.RequestsDialogBuilder(
            devkitActivity,
            Session.getActiveSession(),
            dialogParams)
          ).setOnCompleteListener(dialogCallback).build();
          requestsDialog.show();
        }
      };
      devkitActivity.runOnUiThread(runnable);
    } else if (method.equalsIgnoreCase("share") || method.equalsIgnoreCase("share_open_graph")) {
      Boolean canPresentShareDialog = FacebookDialog.canPresentShareDialog(
        devkitActivity,
        FacebookDialog.ShareDialogFeature.SHARE_DIALOG
      );

      if (canPresentShareDialog) {
        Runnable runnable = new Runnable() {
          public void run() {
            // Publish the post using the Share Dialog
            FacebookDialog shareDialog = new FacebookDialog.ShareDialogBuilder(devkitActivity)
              .setName(dialogParams.getString("name"))
              .setCaption(dialogParams.getString("caption"))
              .setDescription(dialogParams.getString("description"))
              .setLink(dialogParams.getString("href"))
              .setPicture(dialogParams.getString("picture"))
              .build();
            shareDialog.present();
          }
        };

        devkitActivity.runOnUiThread(runnable);
      } else {
        // Fallback. For example, publish the post using the Feed Dialog
        Runnable runnable = new Runnable() {
          public void run() {
            WebDialog feedDialog = (new WebDialog.FeedDialogBuilder(
              devkitActivity,
              Session.getActiveSession(),
              dialogParams)
            ).setOnCompleteListener(dialogCallback).build();
            feedDialog.show();
          }
        };
        devkitActivity.runOnUiThread(runnable);
      }
    } else {
      sendResponse(getErrorResponse("unsupported method"), requestId);
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
      logger.log("{facebook} Exception processing event:", e.getMessage());
    }

    JSONObject res = new JSONObject();
    try {
      res.put("state", "closed");
    } catch (JSONException e) {
      onJSONException(e);
    }

    sendResponse(res, null, requestId);
  }

  // ---------------------------------------------------------------------------
  // Facebook Interface Utilities
  // ---------------------------------------------------------------------------


  private static final Set<String> publishPermissionsSet = new HashSet<String>() {
    {
      add("ads_management");
      add("create_event");
      add("rsvp_event");
    }
  };

  private boolean isPublishPermission(String permission) {
    return permission != null &&
      (permission.startsWith("publish")) ||
      (permission.startsWith("manage")) ||
      publishPermissionsSet.contains(permission);
  }

  /**
   * Check if active session is open
   *
   * @return boolean
   */

  public boolean checkActiveSession(Session session) {
    if (session != null && session.isOpened()) {
      return true;
    } else {
      return false;
    }
  }

  /**
   * Create a Facebook Response object that matches the one for the Javascript
   * SDK
   *
   * @return JSONObject - the response object
   */

  public JSONObject getResponse() {
    String response;
    final Session session = Session.getActiveSession();
    if (checkActiveSession(session)) {
      Date today = new Date();
      long expirationTime = session.getExpirationDate().getTime();
      long expiresTimeInterval = (expirationTime - today.getTime()) / 1000L;
      long expiresIn = (expiresTimeInterval > 0) ? expiresTimeInterval : 0;
      // Make list of grantedScopes
      final List<String> permissions = session.getPermissions();
      StringBuilder sb = new StringBuilder();
      String comma = ",";
      for (String perm : permissions) {
        sb.append(perm).append(comma);
      }
      sb.setLength(sb.length() - comma.length());
      String grantedScopes = sb.toString();

      response = "{"
        + "\"status\": \"connected\","
        + "\"authResponse\": {"
        + "\"accessToken\": \"" + session.getAccessToken() + "\","
        + "\"expiresIn\": \"" + expiresIn + "\","
        + "\"session_key\": true,"
        + "\"sig\": \"...\","
        + "\"grantedScopes\": \"" + grantedScopes + "\","
        + "\"userID\": \"" + userID + "\""
        + "}"
        + "}";
    } else {
      response = "{"
        + "\"status\": \"unknown\""
        + "}";
    }
    try {
      return new JSONObject(response);
    } catch (JSONException e) {

      e.printStackTrace();
    }
    return new JSONObject();
  }

  /**
   * Create JSON object for facebook err request error
   *
   * @return JSONObject
   */

  public JSONObject getFacebookRequestError(FacebookRequestError e) {
    JSONObject err = new JSONObject();
    JSONObject res = new JSONObject();

    try {
      err.put("code", e.getErrorCode());
      err.put("type", e.getErrorType());
      err.put("message", e.getErrorMessage());
      res.put("error", err);
    } catch (JSONException exception) {
      onJSONException(exception);
    }

    return res;
  }

  /**
   * Create JSON object to be returned to JS
   */

  public JSONObject getErrorResponse(Exception err, String msg, int code) {
    if (err instanceof FacebookServiceException) {
      return getFacebookRequestError(
        ((FacebookServiceException) err).getRequestError()
      );
    }

    if (err instanceof FacebookDialogException) {
      code = ((FacebookDialogException) err).getErrorCode();
    }

    if (msg == null) {
      msg = err.getMessage();
    }

    JSONObject jsonError = new JSONObject();
    JSONObject ret = new JSONObject();

    try {
      jsonError.put("code", code);
      jsonError.put("message", msg);
      ret.put("error", jsonError);
    } catch (JSONException e) {
      onJSONException(e);
      ret = new JSONObject();
    }

    return ret;
  }

  private JSONObject getErrorResponse(String msg) {
    JSONObject response = new JSONObject();
    try {
      response.put("error", msg);
    } catch (JSONException e) {
      log("JSON exception while constructing error response");
    }

    return response;
  }

  private void onSessionStateChange(SessionState state, Exception exception) {
    log("onSessionStateChange:", state.toString());

    boolean userCanceled = exception != null &&
      exception instanceof FacebookOperationCanceledException;

    if (userCanceled) { handleError(exception, activeRequest); return; }

    final Session session = Session.getActiveSession();
    if (state == SessionState.CLOSED_LOGIN_FAILED) {
      handleError(exception, activeRequest);
      return;
    } else if (state.isOpened()) {
      Request.newGraphPathRequest(session, "/me", new Request.Callback() {
        @Override
        public void onCompleted(Response res) {
          if (res.getError() != null) {
            logger.log("\t", res.getError());
            sendResponse(getFacebookRequestError(res.getError()), null, activeRequest);
          } else {
            // Parse JSON response
            try {
              JSONObject json = new JSONObject(res.getRawResponse());
              logger.log("{facebook} /me JSON", json);
              userID = json.getString("id");
              sendResponse(getResponse(), null, activeRequest);
              emitStatusChangeEvents(Session.getActiveSession().getState());
            } catch (JSONException e) {
              onJSONException(e);
              return;
            }
          }
        }
      }).executeAsync();
    } else {
      emitStatusChangeEvents(state);
    }
  }

  public static final int INVALID_ERROR = -2;

  private void emitStatusChangeEvents(SessionState state){
    if (state == SessionState.OPENED) {
      JSONObject payload = getResponse();
      sendEvent("auth.login", payload);
      sendEvent("auth.statusChange", payload);
    } else if (state == SessionState.OPENED_TOKEN_UPDATED) {
      JSONObject payload = getResponse();
      sendEvent("auth.authResponseChanged", payload);
    } else if (state == SessionState.CLOSED) {
      JSONObject payload = new JSONObject();
      try {
        payload.put("status", "unknown");
        payload.put("authResponse", JSONObject.NULL);
      } catch (JSONException e) {
        // nope
      }
      sendEvent("logout", payload);
      sendEvent("auth.statusChange", payload);
    }
  }

  private static void sendEvent(String event, Object payload) {
    String _payload = "";
    if (payload instanceof JSONObject) {
      _payload = payload.toString();
    } else if (payload instanceof String) {
      _payload = (String)payload;
    } else {
      log("sendEvent cannot coerce payload to string");
    }

    PluginManager.sendEvent(event, "FacebookPlugin", _payload);
  }

  private void sendResponse(Object res, String err, Integer requestId) {
    if (activeRequest == requestId) { activeRequest = null; }

    String response = "";

    if (res instanceof JSONObject) {
      response = res.toString();
    } else if (res instanceof String) {
      response = (String) res;
    }

    log("sendResponse", "requestId:", requestId);
    PluginManager.sendResponse(response, err, requestId);
  }

  private void sendResponse(Object res, Integer requestId) {
    sendResponse(res, null, requestId);
  }

  public static void log(Object... args) {
    Object[] newArgs = new Object[args.length + 1];
    newArgs[0] = "{facebook}";
    System.arraycopy(args, 0, newArgs, 1, args.length);
    logger.log(newArgs);
  }

  private void handleError(Exception e, Integer requestId) {
    String msg;
    int code = INVALID_ERROR;

    if (e instanceof FacebookOperationCanceledException) {
      msg = "User cancelled dialog";
      code = 4201;
    } else if (e instanceof FacebookDialogException) {
      msg = "Dialog exception: " + e.getMessage();
    } else {
      msg = e.getMessage();
    }

    JSONObject res = getErrorResponse(e, msg, code);

    sendResponse(res, null, requestId);
  }

  // ---------------------------------------------------------------------------
  // Plugin Interface Methods
  // ---------------------------------------------------------------------------

  public void onCreateApplication(Context applicationContext) {
    _context = applicationContext;
  }

  public void onCreate(Activity activity, Bundle savedInstanceState) {
    _activity = activity;

    PackageManager manager = _activity.getPackageManager();
    try {
      Bundle meta = manager.getApplicationInfo(_activity.getPackageName(), PackageManager.GET_META_DATA).metaData;
      if (meta != null) {
        _facebookAppID = meta.get("FACEBOOK_APP_ID").toString();
        _facebookDisplayName = meta.get("FACEBOOK_DISPLAY_NAME").toString();
      }

      JSONObject ready = new JSONObject();
      try { ready.put("status", "OK"); } catch (JSONException e) {}
      PluginManager.sendEvent("FacebookPluginReady", "FacebookPlugin", ready);

      // TODO track session
      // _tracker = new SessionTracker(_context, new Session.StatusCallback() {
      //   @Override
      //   public void call(Session session, SessionState state, Exception exception) {
      //   }
      // }, null, false);
    } catch (Exception e) {
      logger.log("{facebook} Exception on start:", e.getMessage());
    }

    Settings.addLoggingBehavior(LoggingBehavior.REQUESTS);
  }

  public void onResume() {
    // Track app active events
    // TODO add AppEventsLogger support
    // if (_facebookAppID != null) {
    //   AppEventsLogger.activateApp(_context, _facebookAppID);
    //   Uri intentUri = _activity.getIntent().getData();
    // }
    // if (intentUri != null) {
    //   String requestIdParam = intentUri.getQueryParameter("request_ids");
    // }
  }

  public void onStart() {
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

  @Override
  public void onActivityResult(Integer request, Integer result, Intent data) {
    Session session = Session.getActiveSession();

    if (session != null) {
      session.onActivityResult(_activity, request, result, data);
    }
  }
}
