/**
 * The browser plugin implementation is a thin wrapper on window.FB which
 * accounts for the FB javascript async loading.
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
  'init',
  'ui'
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
