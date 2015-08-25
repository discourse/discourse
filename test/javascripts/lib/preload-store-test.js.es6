import { blank } from 'helpers/qunit-helpers';

module("Discourse.PreloadStore", {
  setup: function() {
    PreloadStore.store('bane', 'evil');
  }
});

test("get", function() {
  blank(PreloadStore.get('joker'), "returns blank for a missing key");
  equal(PreloadStore.get('bane'), 'evil', "returns the value for that key");
});

test("remove", function() {
  PreloadStore.remove('bane');
  blank(PreloadStore.get('bane'), "removes the value if the key exists");
});

asyncTestDiscourse("getAndRemove returns a promise that resolves to null", function() {
  expect(1);

  PreloadStore.getAndRemove('joker').then(function(result) {
    blank(result);
    start();
  });
});

asyncTestDiscourse("getAndRemove returns a promise that resolves to the result of the finder", function() {
  expect(1);

  var finder = function() { return 'batdance'; };
  PreloadStore.getAndRemove('joker', finder).then(function(result) {
    equal(result, 'batdance');
    start();
  });

});

asyncTestDiscourse("getAndRemove returns a promise that resolves to the result of the finder's promise", function() {
  expect(1);

  var finder = function() {
    return new Ember.RSVP.Promise(function(resolve) { resolve('hahahah'); });
  };

  PreloadStore.getAndRemove('joker', finder).then(function(result) {
    equal(result, 'hahahah');
    start();
  });
});

asyncTestDiscourse("returns a promise that rejects with the result of the finder's rejected promise", function() {
  expect(1);

  var finder = function() {
    return new Ember.RSVP.Promise(function(resolve, reject) { reject('error'); });
  };

  PreloadStore.getAndRemove('joker', finder).then(null, function(result) {
    equal(result, 'error');
    start();
  });

});

asyncTestDiscourse("returns a promise that resolves to 'evil'", function() {
  expect(1);

  PreloadStore.getAndRemove('bane').then(function(result) {
    equal(result, 'evil');
    start();
  });
});
