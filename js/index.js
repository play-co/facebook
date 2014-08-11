import device;
import lib.PubSub;

var appId = CONFIG.modules.facebook && CONFIG.modules.facebook.appID;
if (!appId || appId == 'mockid') {
	import .mock.pluginImpl as pluginImpl;
} else if (device.name == 'browser') {
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
	this.init = function () {
		this.subscribe('_statusChanged', this, '_onStatusChanged');
	}

	this._onStatusChanged = function (evt) {
		if (evt.status != this._status) {
			this._status = evt.status;
			logger.log("facebook status", this._status);
			this.publish('StatusChanged', this._status);
		}
	}

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

	this.getPhotoURL = function (userOrID) {
		var id = userOrID;
		if (typeof userOrID == 'object') {
			id = userOrID.id;
		}

		var url;
		if (/^\d+$/.test(id)) {
			url = "http://graph.facebook.com/" + id + "/picture?type=large";
		}

		return url;
	}

	this.queryGraph = function(query, cb) {
		pluginImpl.request("fql", {"query": query}, cb);
	}

	this.logout = function(cb) {
		pluginImpl.request("logout", cb);
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
		pluginImpl.request("postStory", opts, cb);
	};

    this.configure = function(config, cb) {
        logger.warn('facebook.configure NOT IMPLEMENTED');
        cb();
    };
});

exports = new Facebook();
GC.plugins.register('FacebookPlugin', exports);
