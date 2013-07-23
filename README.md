# Game Closure DevKit Plugin: Facebook

## Setup

Create a new Facebook developer account on the [Facebook developer website](http://developer.facebook.com).  Create a new Facebook App, and associate it with your iOS/Android app by filling in the fields on the Facebook developer.  Copy the App ID for the Facebook App.

Install the plugin with `basil install facebook`.

Include it in the `manifest.json` file under the "addons" section for your game:

~~~
"addons": [
	"facebook"
],
~~~

Under the Android/iOS sections, you can configure the Facebook plugin:

~~~
	"android": {
		"versionCode": 1,
		"icons": {
			"36": "resources/icons/android36.png",
			"48": "resources/icons/android48.png",
			"72": "resources/icons/android72.png",
			"96": "resources/icons/android96.png"
		},
		"facebookAppID": "285806904898926",
		"facebookDisplayName": "My Facebook App"
	}
~~~

~~~
	"ios": {
		"bundleID": "mmp",
		"appleID": "568975017",
		"version": "1.0.3",
		"icons": {
			"57": "resources/images/promo/icon57.png",
			"72": "resources/images/promo/icon72.png",
			"114": "resources/images/promo/icon114.png",
			"144": "resources/images/promo/icon144.png"
		},
		"facebookAppID": "285806904898926",
		"facebookDisplayName": "My Facebook App"
	},
~~~

## Usage

To use Facebook features in your game, import the `facebook` object:

~~~
import plugins.facebook.facebook as facebook;
~~~

To present a login UI to the user, use the `facebook.login();` method.  For complete documentation see the API reference below.

# facebook object

The Facebook object exposes a number of asynchronous functions that can be used to establish a Facebook session and interact with the Facebook servers.

## Methods:

### facebook.login ( next(isOpen) )

Parameters
:	1. `next(isOpen) {function}` ---Callback function that indicates whether or not the login succeeded.

Returns
:    1. `void`

The `next` callback function first argument is a boolean that is true if the login succeeded.

Example usage:

~~~
facebook.login(function(isOpen) {
	if (isOpen) {
		// Login success
	} else {
		// Login failure
	}
});
~~~

### facebook.loggedin ( next(isOpen) )

Parameters
:	1. `next(isOpen) {function}` ---Callback function that indicates whether or not the user is logged in.

Returns
:    1. `void`

The `next` callback function first argument is a boolean that is true if the user is currently logged in.

Example usage:

~~~
facebook.loggedin(function(isOpen) {
	if (isOpen) {
		// Logged in
	}
});
~~~

### facebook.me ( next(error, me) )

Parameters
:	1. `next(error, me) {function}` ---Callback function that receives the information about the logged-in user.

Returns
:    1. `void`

The `next` callback function first argument is an error code on error, or falsey if the call succeeded.  On success, the second argument will be a `me` object with the following apparent schema:

~~~
{
  "photo_url": "http://graph.facebook.com/100005502420032/picture",
  "id": "100005502420032",
  "name": "Chris Taylor",
  "first_name": "Chris",
  "email": "chris@gameclosure.com"
}
~~~

For `photo_url` you can append "?type=square" or "?type=large" to affect the picture that the Facebook servers return.  See Facebook documentation for other options.

The following additional fields may be reported but do not seem to be filled in by the server:

~~~
{
	"middle_name": "",
	"last_name": "",
	"link": "",
	"username": "",
	"birthday": "",
	"location_id": "",
	"location_name": ""
}
~~~

Example usage:

~~~
facebook.me(function(err, me) {
	if (!err) {
		logger.log("User email:", me.email);
	}
});
~~~

### facebook.friends ( next(error, list) )

Parameters
:	1. `next(error, list) {function}` ---Callback function that contains the list of the user's friends and their information.

Returns
:    1. `void`

The `next` callback function first argument is an error code on error, or falsey if the call succeeded.  On success, the second argument will be a `list` array of objects with the following schema (no emails):

~~~
{
	"photo_url": "http://graph.facebook.com/100002912783751/picture",
	"id": "100002912783751",
	"name": "Teddy Cross",
	"first_name": "Teddy"
}
~~~

Example usage:

~~~
facebook.friends(function(err, friends) {
	if (!err) {
		for (var ii = 0; ii < friends.length; ++ii) {
			logger.log("Friends with:", friends[ii].name);
		}
	}
});
~~~

### facebook.logout ( )

Parameters
:	1. `void`

Returns
:    1. `void`

Log out from Facebook.


Example usage:

~~~
facebook.logout();
~~~
