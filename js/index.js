import device;
import lib.PubSub;
import lib.Callback;

import .mock.pluginImpl as mockImpl;

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

  // Proxy all of the methods due to FB.js async loading
  var methods = [
    'api',
    'getLoginStatus',
    'getAuthResponse',
    'getAccessToken',
    'getUserID',
    'login',
    'logout',
    'share',
    'publish',
    'addFriend',
    'ui'
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
  var impl;
  if (opts.appId === 'mockid') {
    logger.debug('using mock facebook api');
    impl = mockImpl;
  } else if (device.name === 'browser') {
    logger.debug('using browser facebook api');
    impl = window.FB;
  } else {
    logger.debug('using native facebook api');
    impl = window.FB;
  }

  // pluginImpl is a non-enumerable property of the GC FB plugin
  Object.defineProperty(this, 'pluginImpl', {
    value: impl
  });

  // Initialize FB
  this.pluginImpl.init(opts);
};

exports = new Facebook();
GC.plugins.register('FacebookPlugin', exports);
