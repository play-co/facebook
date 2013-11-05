import device;

if (device.name == 'browser') {
	import .browser.pluginImpl as pluginImpl;
} else {
	import .native.pluginImpl as pluginImpl;
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
	var loginCB = [], meCB = [], friendsCB = [], fqlCB = [];

	this.init = function(opts) {
		logger.log("{facebook} Registering for events on startup");

		pluginImpl.pluginOn("facebookState", function(evt) {
			logger.log("{facebook} State updated:", evt.state);

			invokeCallbacks(loginCB, true, evt.state === "open");
		});

		pluginImpl.pluginOn("facebookError", function(evt) {
			logger.log("{facebook} Error occurred:", evt.description);
		});

		pluginImpl.pluginOn("facebookMe", function(evt) {
			logger.log("{facebook} Got me, error=", evt.error);

			invokeCallbacks(meCB, true, evt.error, evt.user);
		});

		pluginImpl.pluginOn("facebookFriends", function(evt) {
			logger.log("{facebook} Got friends, error=", evt.error);

			invokeCallbacks(friendsCB, true, evt.error, evt.friends);
		});

		pluginImpl.pluginOn("facebookFql", function(evt) {
			logger.log("{facebook} Got FQL, error=", evt.error, evt);

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

		pluginImpl.pluginSend("login");
	};

	this.me = function(next) {
		logger.log("{facebook} Getting me");

		meCB.push(next);

		pluginImpl.pluginSend("getMe");
	}

	this.friends = function(next) {
		logger.log("{facebook} Getting friends");

		friendsCB.push(next);

		pluginImpl.pluginSend("getFriends");
	}

	this.fql = function(query, next) {
		logger.log("{facebook} Initiating FQL");

		fqlCB.push(next);

		pluginImpl.pluginSend("fql", {"query": query});
	}

	this.logout = function(next) {
		logger.log("{facebook} Initiating logout");

		pluginImpl.pluginSend("logout");
	};

	this.loggedin = function(next) {
		logger.log("{facebook} ");

		loginCB.push(next);

		pluginImpl.pluginSend("isOpen");
	}
});

exports = new Facebook();
