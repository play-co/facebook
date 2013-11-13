import ui.TextView as TextView;
import ui.ScrollView as ScrollView;
import plugins.facebook.facebook as fb;
import device;

exports = Class(GC.Application, function () {

	this.initUI = function () {

		// --- facebook test ---

		var buttons = [
				createButton('login', function () {
					fb.login(showResponse);
				}),
				createButton('logout', function () {
					fb.logout(showResponse);
				}),
				createButton('getMe', function () {
					fb.getMe(showResponse);
				}),
				createButton('getFriends', function () {
					fb.getFriends(showResponse);
				}),
				createButton('inviteFriends', function () {
					fb.inviteFriends({message: 'this is a test invite'}, showResponse);
				}),
				createButton('postStory', function () {
					fb.postStory({
							caption: 'try out google!',
							link: 'http://google.com',
							name: 'Google',
							description: 'a search engine'
						}, showResponse);
				}),
				createButton('fql', function () {
					fb.queryGraph("select uid1, uid2 from friend where uid1=me()", showResponse);
				})
			];

		buttons.forEach(function (button) { this.addSubview(button); }, this);

		// --- json response viewer ---

		var showResponse = function (err, res) {
			if (err) {
				this._result.setText('error:\n' + JSON.stringify(err, null, '  '));
			} else {
				this._result.setText('res:\n' + JSON.stringify(res, null, '  '));
			}
		}.bind(this);

		var top = getBottom();
		var scroller = new ScrollView({
				superview: this,
				backgroundColor: '#448',
				scrollX: false,
				x: 10,
				width: this.style.width - 20,
				y: top,
				height: this.style.height - top - 10,
			});

		this._result = new TextView({
			superview: scroller,
			
			size: 12,
			color: 'white',
			multiline: true,
			horizontalAlign: 'left',
			verticalAlign: 'top',

			width: this.style.width - 20,
			autoSize: true,
			fitHeight: true,
			
			autoFontSize: false,
			fontFamily: 'monospace'
		});

		this._result._textFlow.on('ChangeHeight', function (height) {
			scroller.setScrollBounds({
				minY: 0,
				maxY: height
			});
			scroller.scrollTo(0, 0)
		}.bind(this));
	};

	// --- button layout code ---

	var _width = 140;
	var _height = 60;
	var _padding = 10;
	var _row = 0;
	var _col = 0;
	var _numCols = device.width / (_width + _padding) | 0;
	function createButton(text, cb) {
		var button = new TextView({
			backgroundColor: '#88A',
			x: _col * (_width + _padding) + _padding,
			y: _row * (_height + _padding) + _padding,
			opacity: 0.6,
			width: 140,
			height: 60,
			size: 18,
			color: 'white',
			text: text
		}).on('InputSelect', cb)
			.on('InputOver', function () { this.style.opacity = 0.8; this.getAnimation().now({opacity: 1}); })
			.on('InputOut', function () { this.getAnimation().now({opacity: 0.6}); });

		++_col;
		if (_col >= _numCols) {
			_col = 0;
			++_row;
		}

		return button;
	}

	function getBottom() {
		return (_row + (_col ? 1 : 0)) * (_height + _padding) + _padding;
	}

});
