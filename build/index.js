exports.onBeforeBuild = function (common, project, buildOpts, onFinish) {
	if (buildOpts.bodyHTML) {
		buildOpts.bodyHTML.push(
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

	onFinish();
}