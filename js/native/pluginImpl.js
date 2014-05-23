
var _id = 0;
var request = {};

exports.pluginSend = function(evt, params) {
	NATIVE && NATIVE.plugins && NATIVE.plugins.sendEvent &&
		NATIVE.plugins.sendEvent("FacebookPlugin", evt, JSON.stringify(params || {}));
};

exports.pluginOn = function(evt, next) {
	NATIVE && NATIVE.events && NATIVE.events.registerHandler &&
		NATIVE.events.registerHandler(evt, next);
};

exports.request = function (evt, params, cb) {
    if (typeof params === 'function') {
        cb = params;
        params = {};
    }

	NATIVE.plugins.sendRequest("FacebookPlugin", evt, params, function (err, res) {
		if (res && res.resultURL) {
			res.result = parseResultURL(res.resultURL);
		}

		var canceled = false;
		switch (evt) {
			case 'facebookStory':
				canceled = !res.result || !res.result.post_id;
				break;
			case 'facebookInvites':
				canceled = !res.result || !res.result.request;
				break;
		}

		cb && cb(err, res);
	});
};

function parseResultURL(resultURL) {
	var result = {};
	if (resultURL) {
		try {
			var parts = resultURL.split('?');
			parts = parts && parts[1] && parts[1].split('&');
			for (var i = 0, n = parts && parts.length; i < n; ++i) {
				var kvp = parts[i].split('=');
				var key = decodeURIComponent(kvp[0]);
				var value = decodeURIComponent(kvp[1]);
				var match = key.match(/^(.*)\[(\d+)\]$/);
				if (match) {
					key = match[1];
					var index = parseInt(match[2]);
					if (!result[key]) { result[key] = []; }
					result[key][index] = value;
				} else {
					result[key] = value;
				}
			}
		} catch (e) {
			logger.warn(e);
		}
	}

	return result;
}