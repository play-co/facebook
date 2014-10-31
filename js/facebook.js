var Facebook = Class(function () {

	/** CALLBACK TRACKING
	 *
	 *		Due to the asynchronous nature of the plugin we must store the javascript callbacks
	 *		 to execute when we receive an event from the NATIVE code (ios / android / ios).
	 *		To do this we keep a stack of callbacks for each exposed method and invoke them
	 *		 when necessary. Note that we must be careful not to blindly loop over and execute all
	 *		 callbacks on a stack as NEW callbacks could be added as we execute the stack.
	 */

	// Callback stacks for each exposed method
	var callbacks = {
		'login':    [],
		'me':       [],
		'friends':  [],
		'publish':  [],
		'fql':      [],
		'newCATPI': [],
		'request':  []
	};

	// Invokes all the callbacks in a given stack, will optionally clear the stack
	function invokeCallbacks(stackName, clearStack) {
		var callback, n, nl, args, originalStack = [];
		// Pop off the first two arguments (stackName, clearStack) and keep the rest for the callback
		args = Array.prototype.slice.call(arguments);
		args.shift();
		args.shift();
		logger.log("{facebook-js} - invokeCallbacks", stackName, JSON.stringify(args));
		// Because the callback may in turn add something to the stack, we must COPY the stack to prevent newly added callbacks being triggered instantly
		for(n=0, nl=callbacks[stackName].length; n<nl; n++){
			originalStack.push(callbacks[stackName][n]);
		}
		// Are we clearing the stack?
		//   This is ALWAYS true, but I've left the feature here as a previous coder has a use for it, possibly during debugging
		if(clearStack){
			callbacks[stackName].length = 0;
		}
		// Loop and apply the callbacks
		for(n=0, nl=originalStack.length; n<nl; n++){
			callback = originalStack[n];
			if(callback){
				callback.apply(null, args);
			}
		}
	}

	/** NATIVE COMMUNICATION
	 *
	 *		Register event handlers to the NATIVE environment (ios / android / browser)
	 *		 so that we can receive incoming messages and relay them back to the game.
	 *		We must also listen for key events from NATIVE in order to trigger our 
	 *		 callback stack (see above)
	 */

	// Sends an event to the NATIVE environment
	function pluginSend(evt, params) {
		NATIVE && NATIVE.plugins && NATIVE.plugins.sendEvent && NATIVE.plugins.sendEvent("FacebookPlugin", evt, JSON.stringify(params || {}));
	}
	// Registers a callback to a NATIVE event
	function pluginOn(evt, callback) {
		NATIVE && NATIVE.events && NATIVE.events.registerHandler && NATIVE.events.registerHandler(evt, callback);
	}

	/** STARTUP
	 *
	 *		When the game makes a call to an exposed method (login, me, friends etc.), we should:
	 *			1 - Add the users callback to the relevant stack
	 *			2 - Sent a message to NATIVE
	 *			3 - Wait for a response from NATIVE
	 *			4 - Trigger the users callbacks on the stack
	 */

	// On startup
	this.init = function(opts) {
		logger.log("{facebook-js} Registering for events on startup");


		// Log errors for debugging purposes
		pluginOn("facebookError", function(evt) {
			logger.log("{facebook-js} Error occurred:", evt.description);
		});

		// (are we) logged in?
		this.loggedin = function(callback) {
			logger.log("{facebook-js} Are we logged in?");
			callbacks.login.push(callback);
			pluginSend("isOpen");
		};
		// Login
		this.login = function(callback) {
			logger.log("{facebook-js} Initiating login");
			callbacks.login.push(callback);
			pluginSend("login");
		};
		// We get state changes in response to various events, here it relates to both 'login' and 'loggedin'
		pluginOn("facebookState", function(evt) {
			logger.log("{facebook-js} State updated:", evt.state);
			invokeCallbacks('login', true, evt.state === "open", evt);
		});

		// Logout - there is no callback for logout due to the fact that NATIVE only returns general state changes (above) without the context of the method that triggered the state change.
		//  this should probably be refactored!
		this.logout = function(callback) {
			logger.log("{facebook-js} Initiating logout");
			pluginSend("logout");
		};

		// Get me
		this.me = function(callback) {
			logger.log("{facebook-js} Getting me");
			callbacks.me.push(callback);
			pluginSend("getMe");
		};
		pluginOn("facebookMe", function(evt) {
			logger.log("{facebook-js} Got me, error=", evt.error);
			invokeCallbacks('me', true, evt.error, evt.user);
		});

		// Get my friends
		this.friends = function(callback) {
			logger.log("{facebook-js} Getting friends");
			callbacks.friends.push(callback);
			pluginSend("getFriends");
		};
		pluginOn("facebookFriends", function(evt) {
			logger.log("{facebook-js} Got friends, error=", evt.error);
			invokeCallbacks('friends', true, evt.error, evt.friends);
		});

		// Publish an Open Graph story
		this.publishStory = function(params, callback) {
			logger.log("{facebook-js} Publishing Open Graph story");
			callbacks.publish.push(callback);
			pluginSend("publishStory", params);
		};
		pluginOn("facebookOg", function(evt) {
			logger.log("{facebook-js} Got OG, error=", evt.error);
			invokeCallbacks('publish', true, evt.error, evt.result);
		});

		/** UNDOCUMENTED
		 *
		 *		I've not gone through these third party additions by @hashcube
		 *		 to review or document them, however I will in due course.
		 *		For the time being my requirements are with the methods above.
		 */

		this.newCATPIR = function(next) {
			logger.log("{facebook-js} Initiating CATPIR");
			callbacks.newCATPI.push(next);
			pluginSend("newCATPIR");
		};
		pluginOn("facebooknewCATPI", function(evt) {
			logger.log("{facebook-js} Got CATPI, error=", evt.error);
			invokeCallbacks('newCATPI', true, evt.error, evt.result);
		});

		// ???
		this.didBecomeActive = function() {
			logger.log("{facebook-js} Handling Fast User Switching");
			pluginSend("didBecomeActive");
		};
		// Sample return back data
		//  {
		//      "mMap": {
		//        "to[0]":"659444562",
		//        "to[1]":"100003280950950",
		//        "request":"1436273539929599"
		//        }
		// }
		this.sendRequests = function(params, next) {
			logger.log("{facebook-js} Initiating sendRequests");
			callbacks.request.push(next);
			pluginSend("sendRequests", params);
		};
		pluginOn("facebookRequest", function(evt) {
			logger.log("{facebook-js} request, error=", evt.error);
			invokeCallbacks('request', true, evt.error, evt.response);
		});

		// ???
		this.sendAppEventAchievement = function(achv, max_ms){
			var params = {"name":achv, "max_ms":max_ms};
			pluginSend("sendAppEventAchievement", params);
		};

		// ???
		this.sendAppEventPurchased = function(price, currency, content){
			var params = {"price":price, "currency":currency, "content":content};
			pluginSend("sendAppEventPurchased", params);
		};

		// This is being deprecated!
		//   https://developers.facebook.com/docs/reference/fql/
		this.fql = function(query, next) {
			logger.log("{facebook-js} Initiating FQL");
			callbacks.fql.push(next);
			pluginSend("fql", {"query": query});
		};
		pluginOn("facebookFql", function(evt) {
			logger.log("{facebook-js} Got FQL, error=", evt.error);
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
			invokeCallbacks('fql', true, error, resultObj);
		});

	};

});

exports = new Facebook();