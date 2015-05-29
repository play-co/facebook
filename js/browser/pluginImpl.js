/**
 * The browser plugin implementation is a thin wrapper on window.FB which
 * accounts for the FB javascript async loading.
 */

// Proxy all of the methods due to FB.js async loading
var methods = [
  'init',
  'api',
  'ui',
  'getLoginStatus',
  'login',
  'logout',
  'getAuthResponse',
  'logEvent',
  'logPurchase'
];

methods.forEach(function (method) {
  exports[method] = function () {
    window.FB[method].apply(window.FB, arguments);
  };
});

// Same with object properties.
var properties = [
  'Canvas',
  'XFBML',
  'Event'
];

properties.forEach(function (prop) {
  Object.defineProperty(exports, prop, {
    enumerable: true,
    get: function () {
      return window.FB && window.FB[prop];
    }
  });
});
