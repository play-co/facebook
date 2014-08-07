exports.onBeforeBuild = function (api, app, config, cb) {
	if (config.browser) {
		if (config.isSimulated) {
			config.browser.headHTML.push(
					'<style>',
					'.FB_UI_Dialog { max-width: 100% !important; max-height: 90% !important }',
					'</style>'
				)
		}

		if (config.browser.bodyHTML) {
			config.browser.bodyHTML.push(
				'<div id="fb-root"></div>',
				// Load the SDK asynchronously
				'<script>',
					'(function(d){',
					'var js, id = "facebook-jssdk", ref = d.getElementsByTagName("script")[0];',
					'if (d.getElementById(id)) {return;}',
					'js = d.createElement("script"); js.id = id; js.async = true;',
					'js.src = "//connect.facebook.net/en_US/all.js";',
					'ref.parentNode.insertBefore(js, ref);',
					'}(document));',
				'</script>'
			);
		}
	}

	cb();
}
