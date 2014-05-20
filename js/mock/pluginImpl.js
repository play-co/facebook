var onHandlers = {};
var sendHandlers = {};
var openState = {state: 'closed'}

var me = {
	id: 'facebookid1',
	name: 'FB Testuser'
};

var friends = [
	{
		id: 'facebookid2',
		name: 'Clint Owen'
	},
	{
		id: 'facebookid3',
		name: 'Jean Hampton'
	},
	{
		id: 'facebookid4',
		name: 'Alexis Fields'
	}
];

function showMockedMethodMessage() {
    alert("You are using the mock facebook apis.  To set up a real facebook app, see the weeby-js documentation");
}

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
    showMockedMethodMessage();
	setTimeout(function () {
		cb && cb(null, {
			result: {}
		});
	});
};
sendHandlers.inviteFriends = function (opts, cb) {
    showMockedMethodMessage();
	// https://developers.facebook.com/docs/reference/dialogs/requests/
	setTimeout(function () {
		cb && cb(null, {
			response: {},
		   	canceled: false
		});
	});
};
sendHandlers.postStory = function(opts, cb) {
    showMockedMethodMessage();
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
