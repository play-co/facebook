import device;
import lib.PubSub;

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

function deprecated(name, target) {
	var logged = false;
	return function () {
		if (!logged) {
			logged = true;
			logger.warn(name, 'is deprecated');
		}

		return this[target].apply(this, arguments);
	};
}

var Facebook = Class(lib.PubSub, function () {
	var loginCB = [], fqlCB = [], inviteCbs = [], storyCbs = [], requestCbs = [];

	this.init = function(opts) {
		logger.log("{facebook} Registering for events on startup");

		pluginImpl.pluginOn("facebookState", function(evt) {
			logger.log("{facebook} State updated:", evt.state);

			invokeCallbacks(loginCB, true, evt.state === "open");
		});

		pluginImpl.pluginOn("facebookError", function(evt) {
			logger.log("{facebook} Error occurred:", evt.description);
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

		pluginImpl.pluginOn("facebookRequest", function(evt) {
			try {
				var id = evt.id;
				var data = JSON.parse(evt.data);
				invokeCallbacks(requestCbs, true, evt.error, {
					id: id,
					data: data
				});
			} catch (e) {}
		});
	};

	this.me = deprecated('me', 'getMe');
	this.friends = deprecated('friends', 'getFriends');
	this.loggedin = deprecated('loggedin', 'isLoggedIn');
	this.fql = deprecated('fql', 'queryGraph');

	this.login = function (cb) {
		pluginImpl.request("login", cb);
	};

	this.isLoggedIn = function (cb) {
		pluginImpl.request("isOpen", cb);
	};

	this.getMe = function (cb) {
		pluginImpl.request("getMe", cb);
	}

	this.getFriends = function(cb) {
		pluginImpl.request("getFriends", cb);
	}

	this.queryGraph = function(query, cb) {
		pluginImpl.request("fql", {"query": query}, cb);
	}

	this.logout = function(next) {
		logger.log("{facebook} Initiating logout");

		pluginImpl.pluginSend("logout");
	};



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
		pluginImpl.request("inviteFriends", opts, cb);
	}

	/*
	* See: https://developers.facebook.com/docs/reference/dialogs/feed/
	* opts:
	* caption, link, picture, source, description, properties, actions
	*
	*/
	this.postStory = function(opts, cb) {
		storyCbs.push(cb);
		pluginImpl.request("postStory", opts, cb);
	};
});

exports = new Facebook();
GC.plugins.register('facebook', exports);
