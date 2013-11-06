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
	var loginCB = [], meCB = [], friendsCB = [], fqlCB = [], inviteCbs = [], storyCbs = [];

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

		pluginImpl.pluginOn("facebookInvites", function (evt) {
			var params = evt.params || parseParams(evt.response && evt.response.resultURL);
			var canceled = !evt.params && !params.request;

			// evt.params is from the browser (the JS SDK gives us params parsed)
			invokeCallbacks(inviteCbs, true, evt.error, {
				closed: !evt.completed, // user did not close the dialog with the x
				canceled: canceled, // user hit cancel
				result: params
			});
		});

		pluginImpl.pluginOn("facebookStory", function (evt) {
			var params = evt.result || parseParams(evt.response && evt.response.resultURL);
			invokeCallbacks(storyCbs, true, evt.error, params);
		});
	};

	function parseParams(resultURL) {
		var params = {};
		if (resultURL) {
			try {
				var parts = resultURL.split('?')[1].split('&');
				for (var i = 0, n = parts.length; i < n; ++i) {
					var kvp = parts[i].split('=');
					var key = decodeURIComponent(kvp[0]);
					var value = decodeURIComponent(kvp[1]);
					var match = key.match(/^(.*)\[(\d+)\]$/);
					if (match) {
						key = match[1];
						var index = parseInt(match[2]);
						if (!params[key]) { params[key] = []; }
						params[key][index] = value;
					} else {
						params[key] = value;
					}
				}
			} catch (e) {
				logger.warn(e);
			}
		}

		return params;
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

	/*
	 * Invite some friends
	 *  See: https://developers.facebook.com/docs/reference/dialogs/requests/
	 * 
	 * cb(err, {
	 *    closed : boolean - if the user closed the dialog,
	 *    canceled : boolean - if the user clicked cancel,
	 *    result : {
	 *         to : [ facebook_ids... ] - list of people request was sent to
	 *         request : string - the request object id (full request id is <request_object_id>_<user_id>)
	 *    }
	 * })
	 */
	this.inviteFriends = function (opts, cb) {
		inviteCbs.push(cb);
		pluginImpl.pluginSend("inviteFriends", opts);
	}

	/*
	* See: https://developers.facebook.com/docs/reference/dialogs/feed/
	* opts:
	* caption, link, picture, source, description, properties, actions
	*
	*/
	this.postStory = function(opts, cb) {
		storyCbs.push(cb);
		pluginImpl.pluginSend("postStory", opts);
	};
});

exports = new Facebook();
