/*global waitsFor:true expect:true describe:true beforeEach:true it:true runs:true */

describe("PreloadStore", function() {

  beforeEach(function() {
    PreloadStore.store('bane', 'evil');
  });

  describe("contains", function() {

    it("returns false for a key that doesn't exist", function() {
      expect(PreloadStore.contains('joker')).toBe(false);
    });

    it("returns true for a stored key", function() {
      expect(PreloadStore.contains('bane')).toBe(true);
    });

  });

  describe('getStatic', function() {

    it("returns undefined if the key doesn't exist", function() {
      expect(PreloadStore.getStatic('joker')).toBe(void 0);
    });

    it("returns the the key if it exists", function() {
      expect(PreloadStore.getStatic('bane')).toBe('evil');
    });

    it("removes the key after being called", function() {
      PreloadStore.getStatic('bane');
      expect(PreloadStore.getStatic('bane')).toBe(void 0);
    });

  });

  describe('get', function() {

    it("returns a promise that resolves to null", function() {
      var done, storeResult;
      done = storeResult = null;
      PreloadStore.get('joker').then(function(result) {
        done = true;
        storeResult = result;
      });
      waitsFor((function() { return done; }), "Promise never resolved", 1000);
      runs(function() {
        expect(storeResult).toBe(null);
      });
    });

    it("returns a promise that resolves to the result of the finder", function() {
      var done, finder, storeResult;
      done = storeResult = null;
      finder = function() { return 'evil'; };
      PreloadStore.get('joker', finder).then(function(result) {
        done = true;
        storeResult = result;
      });
      waitsFor((function() { return done; }), "Promise never resolved", 1000);
      runs(function() {
        expect(storeResult).toBe('evil');
      });
    });

    it("returns a promise that resolves to the result of the finder's promise", function() {
      var done, finder, storeResult;
      done = storeResult = null;
      finder = function() {
        var promise = new RSVP.Promise();
        promise.resolve('evil');
        return promise;
      };
      PreloadStore.get('joker', finder).then(function(result) {
        done = true;
        storeResult = result;
      });
      waitsFor((function() { return done; }), "Promise never resolved", 1000);
      runs(function() {
        expect(storeResult).toBe('evil');
      });
    });

    it("returns a promise that resolves to the result of the finder's rejected promise", function() {
      var done, finder, storeResult;
      done = storeResult = null;
      finder = function() {
        var promise = new RSVP.Promise();
        promise.reject('evil');
        return promise;
      };
      PreloadStore.get('joker', finder).then(null, function(rejectedResult) {
        done = true;
        storeResult = rejectedResult;
      });
      waitsFor((function() { return done; }), "Promise never rejected", 1000);
      runs(function() {
        expect(storeResult).toBe('evil');
      });
    });

    it("returns a promise that resolves to 'evil'", function() {
      var done, storeResult;
      done = storeResult = null;
      PreloadStore.get('bane').then(function(result) {
        done = true;
        storeResult = result;
      });
      waitsFor((function() { return done; }), "Promise never resolved", 1000);
      runs(function() {
        expect(storeResult).toBe('evil');
      });
    });

  });

});