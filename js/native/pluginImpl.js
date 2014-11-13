/**
 * get wrapped functions for native plugin
 *
 * @param {string} pluginName
 * @return {NativeInterface<pluginName>}
 */

function getNativeInterface (pluginName) {
  return {
    send: function sendNativeEvent (event, data) {
      data = JSON.stringify(data || {});
      NATIVE.plugins.sendEvent(pluginName, event, data);
    },
    request: function sendNativeRequest (event, data, cb) {
      if (typeof data === 'function') {
        cb = data;
        data = {};
      }

      data = JSON.stringify(data || {});
      NATIVE.plugins.sendRequest(pluginName, event, cb);
    },
    on: function onNativeEvent (event, cb) {
      NATIVE.events.registerHandler(event, cb);
    }
  };
}

/**
 * Native interface for facebook plugin
 */

var nativeFB = getNativeInterface('FacebookPlugin');

/**
 * Wait for native plugin to initialize and then create the facebook interface
 * at window.FB. This event will never fire in the browser.
 */

nativeFB.on('FacebookPluginReady', function () {
  var fbReadyFn = window.fbAsyncInit;
  if (fbReadyFn) {
    fbReadyFn();
  }

  window.FB = createNativeFacebookWrapper();
});

function createNativeFacebookWrapper () {

  // Return an object that looks just like the standard javascript facebook
  // interface
  return {
    init: function FBinit (opts) {
      nativeFB.send('init', opts);
    },
    /**
     * FB.api
     *
     * @param {string} path
     * @param {string} [method]
     * @param {object} [params]
     * @param {function} callback
     */
    api: function FBapi (path, method, params, cb) {
      // Handle overloaded api
      var opts;
      if (typeof method === 'function') {
        // Handle FB.api('/path', cb);
        cb = method;
        opts = {
          params: void 0,
          method: void 0,
          path: path
        };
      } else if (typeof method === 'object') {
        // Handle FB.api('/path', params, cb);
        cb = params;
        opts = {
          params: method,
          method: 'get',
          path: path
        };
      } else if (typeof params === 'function') {
        // Handle FB.api('/path', 'method', cb);
        cb = params;
        opts = {
          params: {},
          method: method,
          path: path
        };
      } else {
        // Handle FB.api('/path', 'method', params, cb);
        opts = {
          params: params, method: method, path: path
        };
      }

      // does path need to be parsed here to send this to the correct native
      // method?
      nativeFB.request('api', opts, cb);
    },
    /**
     * Open some facebook UI.
     * @param {object} params - requires `method` and has various extra things
     * based on the dialog. We currently support the requests dialog.
     * @param {function} cb
     *
     * TODO add support for `payments`, `send`, and `share`
     */
    ui: function FBui (params, cb) {
      nativeFB.request('ui', params, cb);
    },

    /**
     * @method getLoginStatus
     */

    getLoginStatus: function FBgetLoginStatus (cb) {
      nativeFB.request('getLoginStatus', cb);
    },

    /**
     * @method login
     */

    login: function FBlogin (cb, data) {
      nativeFB.request('login', data, cb);
    },

    /**
     * @method logout
     */

    logout: function FBlogout (cb) {
      nativeFB.request('logout', cb);
    },

    /**
     * @method getAuthResponse
     */

    getAuthResponse: function FBgetAuthResponse (cb) {
      nativeFB.request('getAuthStatus', cb);
    },

    /**
     * @property Event
     */

    Event: {
      subscribe: function FBEventSubscribe (event, cb) {
        // TODO
        // native events can only have one listener per event. We need to proxy
        // those events so that there can be multiple listeners.
      },
      unsubscribe: function FBEventUnsubscribe (event, cb) {
        // TODO
      }
    }
  };

}
