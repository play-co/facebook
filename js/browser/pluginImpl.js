import .facebookApp;

var onHandlers = {};
var sendHandlers = {
	'login': function() {
		//TODO get appid from manifest
		facebookApp.init('1402330910004581');
		facebookApp.login(function(response) {
			logger.log(response);
			callOnHandler('facebookState', {state: 'open'});
		});
	},
	'getMe': function() {
		facebookApp.getMe(function(response) {
			//TODO what does an error look like?
			callOnHandler('facebookMe', {error: null, user:response});
		});
	},
	'getFriends': function() {
		facebookApp.getFriends(function(response) {
			//TODO what does an error look like?
			callOnHandler('facebookFriends', {error: null, friends:response});
		});
	}
};
var callOnHandler = function(name, opts) {
	var stateHandler = onHandlers[name];
	stateHandler && stateHandler(opts);
};

facebookApp.withFacebook(function() {
	logger.log('facebook thing succeeded');
});

exports = {
	pluginSend: function(evt, params) {
		logger.log('Handling facebook event', evt, params);
		var handler = sendHandlers[evt];
		handler && handler(params);
	}, 
	pluginOn: function(evt, next) {
		onHandlers[evt] = next;
	}
};
