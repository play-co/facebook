import device;
import lib.PubSub;
import lib.Callback;

// Native is just imported for side effects. It will setup the window.FB object
// just as in the browser.
import .native.pluginImpl as nativeImpl;

/**
 * The devkit Facebook interface.
 * @constructor Facebook
 */
function Facebook () {
  // `onReady` is the only non-standard property on the facebook object.
  this.onReady = new lib.Callback();
  if (window.FB) {
    // Facebook is ready for API calls
    this.onReady.fire();
  } else {
    // Use facebook fbAsyncInit callback
    window.fbAsyncInit = function () {
      this.onReady.fire();
    }.bind(this);
  }

  /**
   * Wrap all of the methods and object properties of the plugin
   * implementation. We don't have a plugin implementation until FB.js is ready
   * and `init` is called on this class.
   */

  // Proxy all of the methods due to FB.js async loading. We wrap init below.
  var methods = [
    'api',
    'ui',
    'getLoginStatus',
    'login',
    'logout',
    'getAuthResponse'
  ];

  var self = this;
  methods.forEach(function (method) {
    self[method] = function () {
      self.pluginImpl[method].apply(self.pluginImpl, arguments);
    };
  });

  // Same with object properties.
  var properties = [
    'Canvas',
    'XFBML',
    'Event'
  ];

  properties.forEach(function (prop) {
    Object.defineProperty(self, prop, {
      enumerable: true,
      get: function () {
        return self.pluginImpl[prop];
      }
    });
  });

  // Same with AppEvent methods
  this.AppEvents = {};
  var aeMethods = [
    'logEvent',
    'logPurchase'
  ];

  aeMethods.forEach(function (method) {
    self.AppEvents[method] = function () {
      try {
        self.pluginImpl.AppEvents[method].apply(self.pluginImpl.AppEvents, arguments);
      } catch(err) {
        console.log(err);
      }
    };
  });

  // Same with AppEvent properties
  var aeProperties = [
    'EventNames',
    'ParameterNames'
  ];

  aeProperties.forEach(function (prop) {
    Object.defineProperty(self.AppEvents, prop, {
      enumerable: true,
      get: function () {
        return self.pluginImpl.AppEvents[prop];
      }
    });
  });

  // pluginImpl is a non-enumerable property of the GC FB plugin
  Object.defineProperty(this, 'pluginImpl', {
    get: function () { return window.FB; }
  });
}

/**
 * Initialize the facebook plugin. This is a lightweight wrapper around the
 * FB.init method.
 *
 * @example
 *
 *    FB.initFacebook({
 *      appId      : '{your-app-id}',
 *      status     : true,
 *      xfbml      : true,
 *      version    : 'v2.0'
 *    });
 *
 * The appId `mockid` will result in a mock implementation for offline testing
 *
 */

Facebook.prototype.init = function (opts) {
  // Initialize FB
  this.pluginImpl.init(opts);
};

exports = new Facebook();
