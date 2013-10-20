var clock, original, debounced, originalPromiseResolvesWith, callback;

var nothingFired = function(additionalMessage) {
  ok(!original.called, "original function is not called " + additionalMessage);
  ok(!callback.called, "debounced promise is not resolved " + additionalMessage);
};

var originalAndCallbackFiredOnce = function(additionalMessage) {
  ok(original.calledOnce, "original function is called once " + additionalMessage);
  ok(callback.calledOnce, "debounced promise is resolved once " + additionalMessage);
};

module("Discourse.debouncePromise", {
  setup: function() {
    clock = sinon.useFakeTimers();

    originalPromiseResolvesWith = null;
    original = sinon.spy(function() {
      var promise = Ember.Deferred.create();
      promise.resolve(originalPromiseResolvesWith);
      return promise;
    });

    debounced = Discourse.debouncePromise(original, 100);
    callback = sinon.spy();
  },

  teardown: function() {
    clock.restore();
  }
});

test("delays execution till the end of the timeout", function() {
  debounced().then(callback);
  nothingFired("immediately after calling debounced function");

  clock.tick(99);
  nothingFired("just before the end of the timeout");

  clock.tick(1);
  originalAndCallbackFiredOnce("exactly at the end of the timeout");
});

test("executes only once, no matter how many times debounced function is called during the timeout", function() {
  debounced().then(callback);
  debounced().then(callback);

  clock.tick(100);
  originalAndCallbackFiredOnce("(second call was supressed)");
});

test("prolongs the timeout when the debounced function is called for the second time during the timeout", function() {
  debounced().then(callback);

  clock.tick(50);
  debounced().then(callback);

  clock.tick(50);
  nothingFired("at the end of the original timeout");

  clock.tick(50);
  originalAndCallbackFiredOnce("exactly at the end of the prolonged timeout");
});

test("preserves last call's context and params when executing delayed function", function() {
  var firstObj = {};
  var secondObj = {};

  debounced.call(firstObj, "first");
  debounced.call(secondObj, "second");

  clock.tick(100);
  ok(original.calledOn(secondObj), "the context of the second of two subsequent calls is preserved");
  ok(original.calledWithExactly("second"), "param passed during the second of two subsequent calls is preserved");
});

test("can be called again after timeout passes", function() {
  debounced().then(callback);

  clock.tick(100);
  debounced().then(callback);

  clock.tick(100);
  ok(original.calledTwice, "original function is called for the second time");
  ok(callback.calledTwice, "debounced promise is resolved for the second time");
});

test("passes resolved value from the original promise as a param to the debounced promise's callback", function() {
  originalPromiseResolvesWith = "original promise return value";
  debounced().then(callback);

  clock.tick(100);
  ok(callback.calledWith("original promise return value"));
});
