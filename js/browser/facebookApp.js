/**
 * @license
 * This file is part of the Game Closure SDK.
 *
 * The Game Closure SDK is free software: you can redistribute it and/or modify
 * it under the terms of the Mozilla Public License v. 2.0 as published by
 * Mozilla.

 * The Game Closure SDK is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * Mozilla Public License v. 2.0 for more details.

 * You should have received a copy of the Mozilla Public License v. 2.0
 * along with the Game Closure SDK.  If not, see <http://mozilla.org/MPL/2.0/>.
 */

import lib.Callback;

var withFacebook = new lib.Callback();
var _appID;

// create a mock facebook object that lets us call the facebook JS SDK
// synchronously

var FB = {};
wrapFBCall(
  'api', 'getLoginStatus', 'getAuthResponse', 'getAccessToken',
  'getUserID', 'login', 'logout', 'share', 'publish', 'addFriend',
  'init', 'ui'
);

function wrapFBCall() {
  for (var i = 0, n = arguments.length; i < n; ++i) {
    var method = arguments[i];
    /* jshint -W083 */
    FB[method] = function () {
      var args = arguments;
      withFacebook.run(function () {
        GLOBAL.FB[method].apply(GLOBAL.FB, args);
      });
    };
    /* jshint +W083 */
  }
}

// run any callback function after the FB JS SDK loads
exports.withFacebook = function () {
  withFacebook.forward(arguments);
};

// start the init process
var INIT_TIMEOUT = CONFIG.modules.facebook &&
  CONFIG.modules.facebook.timeout ||
  20000;

exports.init = function (opts) {
  logger.log('Initializing Facebook canvas app with ID:', opts.appID);
  _appID = opts.appID;

  if (GLOBAL.FB) {
    _onload(opts);
  } else {
    withFacebook.runOrTimeout(function () {
      logger.log('async init succeeded');
    }, function () {
      logger.log('async init timed out');
      exports.timedOut = true;
    }, INIT_TIMEOUT);

    // this will run when/if the facebook code loads
    window.fbAsyncInit = bind(this, _onload, opts);
  }
};

function _onload(opts) {
  GLOBAL.FB.init(opts);

  if (exports.timedOut) {
    exports.timedOut = false;
  }

  logger.log('facebook initialized');
  withFacebook.fire(GLOBAL.FB);
}

exports.getMe = function(cb) {
  FB.api('/me', cb);
};

exports.login = function(cb) {
  FB.login(cb, {scope: 'public_profile, user_friends'});
};

exports.logout = function(cb) {
  FB.logout(cb);
};

exports.isOpen = function(cb) {
  FB.getLoginStatus(cb);
};

exports.fql = function(params, cb) {
  var encodedQuery = encodeURIComponent(params.query);
  console.log(encodedQuery);
  FB.api('/fql?q=' + encodedQuery, cb);
};

exports.getFriends = function(cb) {
  FB.api('/me/friends', cb);
};

exports.postStory = function(params, cb) {
  params = merge({method: 'feed'}, params);
  FB.ui(params, cb);
};

// export the FB API functions
exports.FB = FB;
