import .facebookApp;

var onHandlers = {};
var appId = CONFIG.addons.facebook && CONFIG.addons.facebook.appID;
if (!appId) {
	logger.warn('couldn\'t find appId in manifest');
}
facebookApp.init(appId);
facebookApp.withFacebook(function () {
	FB.Event.subscribe('auth.authResponseChange', function (response) {
		GC.plugins.getPlugin('FacebookPlugin').publish('_statusChanged', response);
	});
});

var sendHandlers = {};
sendHandlers.login = function(params, cb) {
	//TODO get appid from manifest
	facebookApp.isOpen(function(response) {
		if (response.status !== 'connected') {
			facebookApp.login(function(response) {
				logger.log(response);
				cb && cb(null, {state: 'open'});
			});
		} else {
			cb && cb(null, {state: 'open'});
		}
	});
};
sendHandlers.logout = function(params, cb) {
	facebookApp.logout(function(response) {
		cb && cb(null, {state: 'closed'});
	});
};
sendHandlers.isOpen = function(params, cb) {
	facebookApp.isOpen(function(response) {
		var open = response.status == 'connected';
		cb && cb(null, {state: open ? 'open': 'closed'});
	});
};
sendHandlers.getMe = function(params, cb) {
	facebookApp.getMe(function(response) {
		if (response.error) {
			cb && cb(response.error);
		} else {
			cb && cb(null, {user: response});
		}
	});
};
sendHandlers.getFriends = function(params, cb) {
	facebookApp.getFriends(function(response) {
		if (response.error) {
			cb && cb(response.error);
		} else {
			cb && cb(null, {friends: response.data});
		}
	});
};
sendHandlers.fql = function(query, cb) {
	facebookApp.fql(query, function(response) {
		cb && cb(null, {result: response});
	});
};
sendHandlers.inviteFriends = function (opts, cb) {
	// https://developers.facebook.com/docs/reference/dialogs/requests/
	opts = merge({method: 'apprequests'}, opts);
	facebookApp.FB.ui(opts, function (response) {
		// Note: no known error handling on the web...
		cb && cb(null, {
			response: response,
			canceled: !response
		});
	});
};
sendHandlers.postStory = function(opts, cb) {
	facebookApp.postStory(opts, function (response) {
		// Note: no known error handling on the web...
		cb && cb(null, {
			response: response,
			canceled: !response
		});
	});
}

exports = {
	pluginSend: function(evt, params) {
		var handler = sendHandlers[evt];
		handler && handler(params);
	}, 
	pluginOn: function(evt, next) {
		onHandlers[evt] = next;
	},
	request: function (evt, params, cb) {
		if (typeof params == 'function') {
			cb = params;
			params = null;
		}

		var handler = sendHandlers[evt];
		handler && handler(params, cb);
	}
};
