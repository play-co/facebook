# Game Closure DevKit Plugin: Facebook

## Usage

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
