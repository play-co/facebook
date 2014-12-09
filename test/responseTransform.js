
var transforms = jsio('../js/native/ResponseTransform');
var expectedResponse = {
  request: '315106545346711',
  to: [
    '1382238695404387',
    '1382809425347124',
    '1378760385753296'
  ]
};

describe('response transforms', function () {
  before(function () {
    this.config = {
      appId: '123'
    };
  });
  describe('base transforms', function () {
    before(function () {
      this.transform = new transforms.ResponseTransform(this.config);
    });

    it('should cache the config object from object creation', function () {
      assert.equal(this.transform.config, this.config);
    });

    describe('#ui', function () {
      it('should pass the result through', function () {
        var res = {hi: 'hi'};
        assert.equal(res, this.transform.ui({}, res));
      });
    });

    describe('#api', function () {
      it('should pass the result through', function () {
        var res = {hi: 'hi'};
        assert.equal(res, this.transform.api({}, res));
      });
    });
  });

  describe('ios transforms', function () {
    before(function () {
      this.transform = new transforms.IOSResponseTransform();
    });

    describe('#ui', function () {
      describe('apprequests', function () {
        it('should return an empty array when no request is sent', function () {
          var expected = [];
          var actual = this.transform.ui({
            method: 'apprequests'
          }, {urlResponse: 'fbconnect://success'});

          assert(Array.isArray(actual), 'actual is not array');
          assert.equal(expected.length, actual.length);
        });
      });
      it('should pass through undefined', function () {
        assert.equal(void 0, this.transform.ui({}, void 0));
      });
      it('should parse urlResponse into an object', function () {
        var iosUrlResponse = {
          urlResponse: 'fbconnect://success?request=315106545346711&to%5B0%5D' +
            '=1382238695404387&to%5B1%5D=1382809425347124&to%5B2%5D=137876038' +
            '5753296'
        };
        var expected = expectedResponse;

        var actual = this.transform.ui({
          method: 'apprequests'
        }, iosUrlResponse);

        assert.equal(
          actual.request, expected.request, 'request fields do not match'
        );
        assert(Array.isArray(actual.to), 'parsed `to` is not array');
        expected.to.forEach(function (id) {
          assert(actual.to.indexOf(id) !== -1, 'did not find id in actual.to');
        });
      });
    });
  });

  describe('android transform', function () {
    before(function () {
      this.transform = new transforms.AndroidResponseTransform();
    });
    describe('#ui', function () {
      describe('apprequests method', function () {
        before(function () {
          this.populatedResponse = {
            'to[0]': '1382238695404387',
            'to[2]': '1382809425347124',
            'request': '315106545346711',
            'to[1]': '1378760385753296'
          };
          this.expectedResponse = expectedResponse;
        });
        after(function () {
          this.populatedResponse = void 0;
          this.expectedResponse = void 0;
        });

        it('should return an empty array if no requests are sent', function () {
          var expected = [];
          var actual = this.transform.ui({
            method: 'apprequests'
          }, {});

          assert(Array.isArray(actual), 'actual is not array');
          assert.equal(expected.length, actual.length);
        });

        it('should decode query string arrays', function () {
          var expected = this.expectedResponse;
          var actual = this.transform.ui({
            method: 'apprequests'
          }, this.populatedResponse);

          assert.equal(
            actual.request, expected.request, 'request fields do not match'
          );
          assert(Array.isArray(actual.to), 'parsed `to` is not array');
          expected.to.forEach(function (id) {
            assert(actual.to.indexOf(id) !== -1, 'missing id in actual.to');
          });
        });
      });

      it('should pass populated responses through', function () {
        var res = {hi: 'hi'};
        assert.equal(res, this.transform.ui({}, res));
      });
    });
  });
});
