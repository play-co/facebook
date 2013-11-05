
exports = {
	pluginSend: function(evt, params) {
	NATIVE && NATIVE.plugins && NATIVE.plugins.sendEvent &&
		NATIVE.plugins.sendEvent("FacebookPlugin", evt,
				JSON.stringify(params || {}));
	}, 
	pluginOn: function(evt, next) {
	NATIVE && NATIVE.events && NATIVE.events.registerHandler &&
		NATIVE.events.registerHandler(evt, next);
	}
};
