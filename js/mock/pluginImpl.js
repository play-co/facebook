var onHandlers = {};
var sendHandlers = {};
var openState = {state: 'closed'}

var me = {
	id: 'facebookid1',
	name: 'You'
};

var friends = [
	{
		id: 'facebookid2',
		name: 'friend1'
	},
	{
		id: 'facebookid3',
		name: 'friend2'
	},
	{
		id: 'facebookid4',
		name: 'friend3'
	}
];

sendHandlers.login = function(params, cb) {
	setTimeout(function () {
		openState.state = 'open';
		cb && cb(null, openState);
	});
};
sendHandlers.logout = function(params, cb) {
	setTimeout(function () {
		openState.state = 'closed';
		cb && cb(null, openState);
	});
};
sendHandlers.isOpen = function(params, cb) {
	setTimeout(function () {
		cb && cb(null, openState);
	});
};
sendHandlers.getMe = function(params, cb) {
	setTimeout(function () {
		cb && cb(null, {
			user: me
		});
	});
};
sendHandlers.getFriends = function(params, cb) {
	setTimeout(function () {
		cb && cb(null, {
			friends: friends
		});
	});
};
sendHandlers.fql = function(query, cb) {
	// ... this may be hard to mock
	setTimeout(function () {
		cb && cb(null, {
			result: {}
		});
	});
};
sendHandlers.inviteFriends = function (opts, cb) {
	// https://developers.facebook.com/docs/reference/dialogs/requests/
	setTimeout(function () {
		cb && cb(null, {
			response: {},
		   	canceled: false
		});
	});
};
sendHandlers.postStory = function(opts, cb) {
	setTimeout(function () {
		cb && cb(null, {
			response: {},
		   	canceled: false
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
