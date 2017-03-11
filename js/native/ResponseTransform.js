import std.uri;

/**
 * Transform responses for certain methods that are more easily resolved in JS
 * than in native.
 *
 * @class ResponseTransform
 */

function ResponseTransform (config) {
  this.config = config;
}

ResponseTransform.prototype.ui = function ui (req, res) {
  return res;
};

ResponseTransform.prototype.api = function api (req, res) {
  return res;
};

ResponseTransform.getTransformer = function getTransformer () {
  import device;

  if (device.isIOS) {
    return new IOSResponseTransform();
  } else if (device.isAndroid) {
    return new AndroidResponseTransform();
  } else {
    logger.warn('{facebook} Unexpected device type detected');
    return new ResponseTransform();
  }
};

/**
 * Transform class for iOS
 *
 * @class
 */

function IOSResponseTransform () {
  ResponseTransform.constructor.apply(this, arguments);
}

IOSResponseTransform.prototype = new ResponseTransform();

// todo import another url package. this won't work in browser/on device
IOSResponseTransform.prototype.ui = function ui (req, res) {
  if (!res) {
    return undefined;
  } else if (res.error) {
    return res;
  }

  if (res.urlResponse) {
    var uri = new std.uri(res.urlResponse);
    var query = std.uri.parseQuery(uri._query);

    res = parseQueryObject(query);

    if (Object.keys(res).length === 0 && req.method === 'apprequests') {
      return [];
    }

    return res;
  }
};

var rArray = /\[\d+\]$/;
function parseQueryObject (query) {
  var res = {};
  Object.keys(query).forEach(function (key) {
    var val = query[key];
    if (rArray.test(key)) {
      var arrayName = key.split('[')[0];
      if (Array.isArray(res[arrayName])) {
        res[arrayName].push(val);
      } else {
        res[arrayName] = [val];
      }
    } else {
      res[key] = val;
    }
  });
  return res;
}

/**
 * Transform class for android
 *
 * @class
 */

function AndroidResponseTransform () {
  ResponseTransform.constructor.apply(this, arguments);
}

AndroidResponseTransform.prototype = new ResponseTransform();

AndroidResponseTransform.prototype.ui = function ui (req, res) {
  if (res && res.error) { return res; }

  if (req.method === 'apprequests') {
    if (res && typeof res === 'object') {
      if (Object.keys(res).length === 0) {
        return [];
      } else {
        return parseQueryObject(res);
      }
    }
  }

  return res;
};

exports.ResponseTransform = ResponseTransform;
exports.IOSResponseTransform = IOSResponseTransform;
exports.AndroidResponseTransform = AndroidResponseTransform;
