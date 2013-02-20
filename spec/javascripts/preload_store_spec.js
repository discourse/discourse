/*global waitsFor:true expect:true describe:true beforeEach:true it:true runs:true */

(function() {

  describe("PreloadStore", function() {
    beforeEach(function() {
      return PreloadStore.store('bane', 'evil');
    });
    describe("contains", function() {
      it("returns false for a key that doesn't exist", function() {
        return expect(PreloadStore.contains('joker')).toBe(false);
      });
      return it("returns true for a stored key", function() {
        return expect(PreloadStore.contains('bane')).toBe(true);
      });
    });
    describe('getStatic', function() {
      it("returns undefined if the key doesn't exist", function() {
        return expect(PreloadStore.getStatic('joker')).toBe(void 0);
      });
      it("returns the the key if it exists", function() {
        return expect(PreloadStore.getStatic('bane')).toBe('evil');
      });
      return it("removes the key after being called", function() {
        PreloadStore.getStatic('bane');
        return expect(PreloadStore.getStatic('bane')).toBe(void 0);
      });
    });
    return describe('get', function() {
      it("returns a promise that resolves to undefined", function() {
        var done, storeResult;
        done = storeResult = null;
        PreloadStore.get('joker').then(function(result) {
          done = true;
          storeResult = result;
        });
        waitsFor((function() {
          return done;
        }), "Promise never resolved", 1000);
        return runs(function() {
          return expect(storeResult).toBe(void 0);
        });
      });
      it("returns a promise that resolves to the result of the finder", function() {
        var done, finder, storeResult;
        done = storeResult = null;
        finder = function() {
          return 'evil';
        };
        PreloadStore.get('joker', finder).then(function(result) {
          done = true;
          storeResult = result;
        });
        waitsFor((function() {
          return done;
        }), "Promise never resolved", 1000);
        return runs(function() {
          return expect(storeResult).toBe('evil');
        });
      });
      it("returns a promise that resolves to the result of the finder's promise", function() {
        var done, finder, storeResult;
        done = storeResult = null;
        finder = function() {
          var promise;
          promise = new RSVP.Promise();
          promise.resolve('evil');
          return promise;
        };
        PreloadStore.get('joker', finder).then(function(result) {
          done = true;
          storeResult = result;
        });
        waitsFor((function() {
          return done;
        }), "Promise never resolved", 1000);
        return runs(function() {
          return expect(storeResult).toBe('evil');
        });
      });
      it("returns a promise that resolves to the result of the finder's rejected promise", function() {
        var done, finder, storeResult;
        done = storeResult = null;
        finder = function() {
          var promise;
          promise = new RSVP.Promise();
          promise.reject('evil');
          return promise;
        };
        PreloadStore.get('joker', finder).then(null, function(rejectedResult) {
          done = true;
          storeResult = rejectedResult;
        });
        waitsFor((function() {
          return done;
        }), "Promise never rejected", 1000);
        return runs(function() {
          return expect(storeResult).toBe('evil');
        });
      });
      return it("returns a promise that resolves to 'evil'", function() {
        var done, storeResult;
        done = storeResult = null;
        PreloadStore.get('bane').then(function(result) {
          done = true;
          storeResult = result;
        });
        waitsFor((function() {
          return done;
        }), "Promise never resolved", 1000);
        return runs(function() {
          return expect(storeResult).toBe('evil');
        });
      });
    });
  });

}).call(this);
