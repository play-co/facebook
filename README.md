devkit-facebook
===============

The devkit facebook plugin provides native support with a matching API to the
JavaScript facebook API.

iOS Support: **Alpha**
Android Support: **NONE**
Browser Support: **100%**

## Setup

Run `devkit install https://github.com/gameclosure/facebook#feature-v2.2` from
your devkit2 application directory. Add `import facebook as FB;` in your
application and you are ready to start integrating facebook with your
application.

### iOS Builds

There are a few keys you need to add to your _manifest.json_. The URL scheme is
just the string "fb" prepended to your app ID.

```json
"addons": {
  "facebook": {
    "facebookAppID": your-app-id,
    "facebookDisplayName": your-app-display-name,
    "facebookURLScheme": "fb" + your-app-id
  }
}
```

## API

The plugin was written such that you can reference the
[Facebook JS docs](facebook_js) as a sole source of truth with a couple of minor
exceptions.

### Ready Detection
The main difference from the facebook API is how you detect when the plugin is
ready. The facebook docs suggest using `window.fbAsyncInit`, but the plugin uses
that internally to detect facebook ready status across native and browser.
Instead, you should use `FB.onReady.run(cb)` where cb is the code you want to
run when facebook is ready.

### FB.init
For native, you also need to pass `displayName` to your FB.init call.

### FB.api
There's probably hiccups with a lot of the endpoints here presently. For
example, the `actions` parameter of [/me/feed][user_feed_docs] is not handled
and will cause errors. At this point, I would recommend against any nested
properties / arrays with this API.


[facebook_js]: https://developers.facebook.com/docs/javascript/reference/v2.2
[user_feed_docs]: https://developers.facebook.com/docs/graph-api/reference/v2.2/user/feed/
