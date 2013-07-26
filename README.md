# Game Closure DevKit Plugin: Facebook

## Setup

Create a new Facebook developer account on the [Facebook developer website](http://developer.facebook.com).  Create a new Facebook App, and associate it with your iOS/Android app by filling in your app details under the "Native iOS App" and "Native Android App" sections.  Copy down the Facebook App ID as you will need it.

#### iOS Setup on Facebook Developer Site

###### Bundle ID

The `Bundle ID` should be the `shortName` in the game's `manifest.json`.

For example:

~~~
	"shortName": "mmp"
~~~

Bundle ID: `mmp` for Facebook.

###### App Store ID

The `iPhone App Store ID` and `iPad App Store ID` fields should be set to your game's App ID on the App Store.  Retrieve this from the Apple Developer site.

###### Configuration

Check: *Native iOS App*

+ Facebook Login: **[X]** Enabled
+ Deep Linking: **[X]** Enabled

#### Android Setup on Facebook Developer Site

###### Package Name

The `Package Name` can be derived from the studio domain from the game's `manifest.json` reversed with the shortName at the end.

For example:

~~~
	"shortName": "mmp",
	"studio": {
		"domain": "gameclosurelabs.com",
	}
~~~

Package Name: `com.gameclosurelabs.mmp` for Facebook.

###### Class Name

The `Class Name` follows the format: `.(SHORTNAME)Activity`.

For example:

~~~
	"shortName": "mmp"
~~~

Class Name: `.mmpActivity` for Facebook.

###### Key Hashes

The `Key Hashes` can be derived using the `keytool` command.

For debug mode on MacOSX or *nix:

~~~
keytool -list -alias androiddebugkey -keystore ~/.android/debug.keystore -v
~~~

(Press enter to skip over the password prompt.)

For Windows the command is the same except the keystore is located under `%HOMEPATH%.android\debug.keystore`.

Copy the SHA1 version of the key.  It will look like: `26:7A:0A:EA:B9:CD:CF:C1:3B:C0:D8:AD:7F:AA:0C:AC:DB:C0:A8:99`.

For release mode keys, provide the keystore you generated for your game and the key alias to the `keytool` command and copy the SHA1 key.

Put both keys in the `Key Hashes` field on the Facebook developer site by pasting them in one a at time.

###### Configuration

Check: *Native Android App*

+ Facebook Login: **[X]** Enabled
+ Deep Linking: **[X]** Enabled

## Plugin Installation and Configuration

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

## FacebookGraphUser object:

When user data for `me` or `friends` is requested, it is returned to your JavaScript code with the following schema:

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
	"location": {
		"city": "",
		"country": "",
		"latitude": "",
		"longitude": "",
		"state": "",
		"street": "",
		"zip": ""
	}
}
~~~

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

The `next` callback function first argument is an error code on error, or falsey if the call succeeded.  On success, the second argument will be a `FacebookGraphUser` object (see above).

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
:	1. `next(error, list) {function}` ---Callback function that receives the list of the user's friends and their information.

Returns
:    1. `void`

The `next` callback function first argument is an error code on error, or falsey if the call succeeded.  On success, the second argument will be a `list` array of `FacebookGraphUser` objects (see above).

For friends the `email` field will not be filled in by the Facebook server.

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

### facebook.fql ( next(error, result) )

Parameters
:	1. `next(error, result) {function}` ---Callback function that receives the FQL result object.

Returns
:    1. `void`

The `next` callback function first argument is an error code on error, or falsey if the call succeeded.  On success, the second argument will be a `result` object containing the results of the FQL query.

Example usage:

~~~
var query = "SELECT uid, name, pic_square FROM user WHERE uid = me() OR uid IN (SELECT uid2 FROM friend WHERE uid1 = me())";

facebook.fql(query, function(err, result) {
	logger.log("FQL result:", JSON.stringify(result, undefined, 4));
});
~~~

The result is an array of objects containing the requested fields:

~~~
LOG Application.js FQL result: [
   {
       "pic_square": "https://fbcdn-profile-a.akamaihd.net/hprofile-ak-ash4/202997_100005502420032_1573835272_q.jpg",
       "uid": 100005502420032,
       "name": "Chris Taylor"
   },
   {
       "pic_square": "https://fbcdn-profile-a.akamaihd.net/hprofile-ak-ash4/186269_201533_1081441402_q.jpg",
       "uid": 201533,
       "name": "Jen Aguilar"
   },
   {
       "pic_square": "https://profile-b.xx.fbcdn.net/hprofile-prn2/275664_300315_1140227486_q.jpg",
       "uid": 300315,
       "name": "Wei Deng"
   },
   …
]
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
