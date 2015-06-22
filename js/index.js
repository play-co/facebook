import device;
import lib.PubSub;
import lib.Callback;


// Native is just imported for side effects. It will setup the window.FB object
// just as in the browser.
import .native.pluginImpl as nativeImpl;

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
