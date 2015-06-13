import device;
import lib.PubSub;
import lib.Callback;

var rDataURI = /^data:image\/png;base64,/;

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


  // temp - directly call
  // TODO: refactor to match other api
  //   - move to native/pluginImpl
  this.shareImage = function (opts, cb) {
    logger.log("facebook - sharing image");
    opts = JSON.parse(JSON.stringify(opts));

    if (!opts.image && typeof opts.image !== 'undefined') {
      // if it's an empty string or some falsey value other than undefined,
      // make a copy as to not mutate caller's object and delete the image
      // field.
      delete opts.image;
    } else if (rDataURI.test(opts.image)) {
      opts.image = opts.image.replace(rDataURI, '');
    }

    // save callback
    this._shareCallback = cb;

    NATIVE.plugins.sendRequest('FacebookPlugin', 'shareImage', opts);
  };

  this.onShareCompleted = function () {
    this._shareCallback && this._shareCallback();
    this._shareCallback = null;
  };

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
