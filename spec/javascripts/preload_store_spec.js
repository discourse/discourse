/*global waitsFor:true expect:true describe:true beforeEach:true it:true runs:true */

describe("PreloadStore", function() {

  beforeEach(function() {
    PreloadStore.store('bane', 'evil');
  });

  describe('get', function() {

    it("returns undefined if the key doesn't exist", function() {
      expect(PreloadStore.get('joker')).toBe(undefined);
    });

    it("returns the value if the key exists", function() {
      expect(PreloadStore.get('bane')).toBe('evil');
    });

  });

  describe('remove', function() {

    it("removes the value if the key exists", function() {
      PreloadStore.remove('bane');
      expect(PreloadStore.get('bane')).toBe(undefined);
    });

  });  

  describe('getAndRemove', function() {

    it("returns a promise that resolves to null", function() {
      var done, storeResult;
      done = storeResult = null;
      PreloadStore.getAndRemove('joker').then(function(result) {
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
      PreloadStore.getAndRemove('joker', finder).then(function(result) {
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
        return Ember.Deferred.promise(function(promise) { promise.resolve('evil'); });
      };
      PreloadStore.getAndRemove('joker', finder).then(function(result) {
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
        return Ember.Deferred.promise(function(promise) { promise.reject('evil'); });
      };
      PreloadStore.getAndRemove('joker', finder).then(null, function(rejectedResult) {
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
      PreloadStore.getAndRemove('bane').then(function(result) {
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