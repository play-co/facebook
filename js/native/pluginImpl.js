import lib.PubSub;

/**
 * get wrapped functions for native plugin
 *
 * @param {string} pluginName
 * @return {NativeInterface<pluginName>}
 */

function getNativeInterface (pluginName, opts) {
  opts = opts || {};
  var events = new lib.PubSub();
  var subscribedTo = {};
  GC.plugins.register(pluginName, events);
  return {
    notify: function sendNativeEvent (event, data) {
      data = JSON.stringify(data || {});
      NATIVE.plugins.sendEvent(pluginName, event, data);
    },
    request: function sendNativeRequest (event, data, cb) {
      logger.log('[js] {facebook} sending request', event);
      logger.log('\tdata:', JSON.stringify(data, null, '\t'));

      if (typeof data === 'function') {
        cb = data;
        data = {};
      }

      var fn = cb;

      if (opts.noErrorback) {
        fn = function ignoreErrorParameter (err, res) {
          cb(res || {error: 'no res'});
        };
      }

      NATIVE.plugins.sendRequest(pluginName, event, data, fn);
    },
    subscribe: function onNativeEvent (event, cb) {
      events.subscribe(event, cb);
    },
    unsubscribe: function unsubscribeFromNativeEvent (event, cb) {
      events.unsubscribe(event, cb);
    }
  };
}

/**
 * Native interface for facebook plugin
 */

var nativeFB = getNativeInterface('FacebookPlugin', {noErrorback: true});

/**
 * Wait for native plugin to initialize and then create the facebook interface
 * at window.FB. This event will never fire in the browser.
 */

nativeFB.subscribe('FacebookPluginReady', function () {
  logger.log(
    '[JS] {FaceBook}', '\n\tGot FacebookPluginReady\n\tCreating Wrapper'
  );

  window.FB = createNativeFacebookWrapper();

  logger.log(
    '[JS] {FaceBook}', '\n\tRunning async init'
  );

  var fbReadyFn = window.fbAsyncInit;
  if (fbReadyFn) {
    fbReadyFn();
  }
});

function createNativeFacebookWrapper () {

  // Return an object that looks just like the standard javascript facebook
  // interface
  return {
    init: function FBinit (opts) {
      if (typeof opts.appId === 'number') {
        opts.appId = opts.appId + '';
        logger.warn('coercing appId to string');
      }
      logger.log('[js] {facebook} sending init');
      nativeFB.notify('facebookInit', opts);
      logger.log('[js] {facebook} init done');
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
          path: path
        };
      } else if (typeof method === 'object') {
        // Handle FB.api('/path', params, cb);
        cb = params;
        opts = {
          params: method,
          path: path
        };
      } else if (typeof params === 'function') {
        // Handle FB.api('/path', 'method', cb);
        cb = params;
        opts = {
          method: method,
          path: path
        };
      } else {
        // Handle FB.api('/path', 'method', params, cb);
        opts = {
          params: params, method: method, path: path
        };
      }

      opts.params = opts.params || {};
      opts.method = opts.method || 'get';

      // does path need to be parsed here to send this to the correct native
      // method?
      nativeFB.request('api', opts, cb);
    },
    /**
     * Open some facebook UI.
     * @param {object} params - requires `method` and has various extra things
     * based on the dialog. We currently support the requests dialog.
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
     * @type FBLoginResponse
     * @param {object} AuthResponse
     * @param {string} AuthResponse.accessToken
     * @param {number} AuthResponse.expiresIn
     * @param {string} AuthResponse.grantedScopes
     * @param {string} AuthResponse.signedRequest
     * @param {string} AuthResponse.userID
     * @param {string} status
     */

    /**
     * @method login
     *
     * The callback will be resolved with a {FBLoginResponse}
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
        nativeFB.subscribe(event, cb);
      },
      unsubscribe: function FBEventUnsubscribe (event, cb) {
        nativeFB.unsubscribe(event, cb);
      }
    }
  };

}
