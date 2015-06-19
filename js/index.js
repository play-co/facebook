import device;
import lib.PubSub;
import lib.Callback;

var rDataURI = /^data:image\/png;base64,/;

// Native is just imported for side effects. It will setup the window.FB object
// just as in the browser.
import .native.pluginImpl as nativeImpl;

exports.shareImage = function (opts, cb) {
  logger.log("facebook - sharing image");
  opts = JSON.parse(JSON.stringify(opts));

  if (!opts.image) {
    return;
  }

  if (device.isSimulator) {
    window.open(opts.image, '_blank');
    cb && cb();
  } else {
    // save callback
    this._shareCallback = cb;
    if (rDataURI.test(opts.image)) {
      opts.image = opts.image.replace(rDataURI, '');
    }

    if (NATIVE && NATIVE.plugins && NATIVE.plugins.sendRequest) {
      NATIVE.plugins.sendRequest('FacebookPlugin', 'shareImage', opts);
    }
  }
};

exports.onShareCompleted = function () {
  this._shareCallback && this._shareCallback();
  this._shareCallback = null;
};

exports.onReady = new lib.Callback();

if (window.FB) {
  init();
} else {
  // wrap a user's fbAsyncInit functions
  var _asyncInit = window.fbAsyncInit;
  Object.defineProperty(window, 'fbAsyncInit', {
    get: function () { return init; },
    set: function (f) { _asyncInit = f; }
  });
}

function init() {
  var FB = window.FB;
  for (var key in FB) {
    var value = FB[key];
    if (typeof value == 'function') {
      exports[key] = bind(FB, value);
    } else {
      exports[key] = value;
    }
  }

  exports.onReady.fire();
  if (_asyncInit && typeof _asyncInit == 'function') {
    _asyncInit.apply(window, arguments);
  }
}
