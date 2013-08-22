function pluginSend(evt, params) {
	NATIVE && NATIVE.plugins && NATIVE.plugins.sendEvent &&
		NATIVE.plugins.sendEvent("FacebookPlugin", evt,
				JSON.stringify(params || {}));
}

function pluginOn(evt, next) {
	NATIVE && NATIVE.events && NATIVE.events.registerHandler &&
		NATIVE.events.registerHandler(evt, next);
}

function invokeCallbacks(list, clear) {
	// Pop off the first two arguments and keep the rest
	var args = Array.prototype.slice.call(arguments);
	args.shift();
	args.shift();

	// For each callback,
	for (var ii = 0; ii < list.length; ++ii) {
		var next = list[ii];

		// If callback was actually specified,
		if (next) {
			// Run it
			next.apply(null, args);
		}
	}

	// If asked to clear the list too,
	if (clear) {
		list.length = 0;
	}
}

var Facebook = Class(function () {
	var loginCB = [], meCB = [], friendsCB = [], fqlCB = [], ogCB = [];

	this.init = function(opts) {
		logger.log("{facebook} Registering for events on startup");

		pluginOn("facebookState", function(evt) {
			logger.log("{facebook} State updated:", evt.state);

			invokeCallbacks(loginCB, true, evt.state === "open");
		});

		pluginOn("facebookError", function(evt) {
			logger.log("{facebook} Error occurred:", evt.description);
		});

		pluginOn("facebookMe", function(evt) {
			logger.log("{facebook} Got me, error=", evt.error);

			invokeCallbacks(meCB, true, evt.error, evt.user);
		});

		pluginOn("facebookOg", function(evt) {
			logger.log("{facebook} Got OG, error=", evt.error);

			invokeCallbacks(ogCB, true, evt.error, evt.result);
		});

		pluginOn("facebookFriends", function(evt) {
			logger.log("{facebook} Got friends, error=", evt.error);

			invokeCallbacks(friendsCB, true, evt.error, evt.friends);
		});

		pluginOn("facebookFql", function(evt) {
			logger.log("{facebook} Got FQL, error=", evt.error);

			var resultObj = evt.result;
			var error = evt.error;

			if (!error) {
				if (typeof resultObj === "string") {
					try {
						resultObj = JSON.parse(resultObj);
					} catch (e) {
						error = "Invalid JSON";
					}
				}
			}

			invokeCallbacks(fqlCB, true, error, resultObj);
		});
	}

	this.login = function(next) {
		logger.log("{facebook} Initiating login");

		loginCB.push(next);

		pluginSend("login");
	};

	this.didBecomeActive = function() {
		logger.log("{facebook} Handling Fast User Switching");

		pluginSend("didBecomeActive");
	}

	this.sendRequests = function(params) {
		logger.log("{facebook} Initiating sendRequests");

		pluginSend("sendRequests", params);
	}

	this.ogCall = function(params, next) {
		logger.log("{facebook} Initiating OpenGraph Action Call");

		ogCB.push(next);

		pluginSend("publishStory", params);
	}

	this.me = function(next) {
		logger.log("{facebook} Getting me");

		meCB.push(next);

		pluginSend("getMe");
	}

	this.friends = function(next) {
		logger.log("{facebook} Getting friends");

		friendsCB.push(next);

		pluginSend("getFriends");
	}

	this.fql = function(query, next) {
		logger.log("{facebook} Initiating FQL");

		fqlCB.push(next);

		pluginSend("fql", {"query": query});
	}

	this.logout = function(next) {
		logger.log("{facebook} Initiating logout");

		pluginSend("logout");
	};

	this.loggedin = function(next) {
		logger.log("{facebook} ");

		loginCB.push(next);

		pluginSend("isOpen");
	}
});

exports = new Facebook();
