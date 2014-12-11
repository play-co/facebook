exports.onBeforeBuild = function (api, app, config, cb) {
  if (config.browser) {
    if (config.isSimulated) {
      config.browser.headHTML.push(
        '<style>',
          '.FB_UI_Dialog {',
            'max-width: 100% !important;',
            'max-height: 90% !important',
          '}',
        '</style>'
      );
    }

    if (config.browser.bodyHTML) {
      config.browser.bodyHTML.push(
        '<script>',
          '(function(d, s, id){',
             'var js, fjs = d.getElementsByTagName(s)[0];',
             'if (d.getElementById(id)) {return;}',
             'js = d.createElement(s); js.id = id;',
             'js.src = "//connect.facebook.net/en_US/all.js";',
             'fjs.parentNode.insertBefore(js, fjs);',
           '}(document, "script", "facebook-jssdk"));',
        '</script>'
      );
    }
  }

  cb();
};
