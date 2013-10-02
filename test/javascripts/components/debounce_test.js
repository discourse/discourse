var clock, original, debounced;

var firedOnce = function(message) {
  ok(original.calledOnce, message);
};

var notFired = function(message) {
  ok(!original.called, message);
};

module("Discourse.debounce", {
  setup: function() {
    clock = sinon.useFakeTimers();
    original = sinon.spy();
    debounced = Discourse.debounce(original, 100);
  },

  teardown: function() {
    clock.restore();
  }
});

test("delays function execution till the end of the timeout", function() {
  debounced();
  notFired("immediately after calling debounced function nothing happens");

  clock.tick(99);
  notFired("just before the end of the timeout still nothing happens");

  clock.tick(1);
  firedOnce("exactly at the end of the timeout the function is executed");
});

test("executes delayed function only once, no matter how many times debounced function is called during the timeout", function() {
  debounced();
  debounced();

  clock.tick(100);
  firedOnce("second call was supressed");
});

test("does not prolong the timeout when the debounced function is called for the second time during the timeout", function() {
  debounced();

  clock.tick(50);
  debounced();

  clock.tick(50);
  firedOnce("function is executed exactly at the end of the original timeout");
});

test("returns a JS timer handle that allows delayed execution to be cancelled before the timeout ends", function() {
  var timerId = debounced();

  clock.tick(50);
  clearTimeout(timerId);

  clock.tick(50);
  notFired("timeout has ended but function was not executed");
});

test("preserves first call's context and params when executing delayed function", function() {
  var firstObj = {};
  var secondObj = {};

  debounced.call(firstObj, "first");
  debounced.call(secondObj, "second");

  clock.tick(100);
  ok(original.calledOn(firstObj), "the context of the first of two subsequent calls is preserved");
  ok(original.calledWithExactly("first"), "param passed during the first of two subsequent calls is preserved");
});

test("can be called again (with a different context and params) after timeout passes", function() {
  var firstObj = {};
  var secondObj = {};

  debounced.call(firstObj, "first");

  clock.tick(100);
  debounced.call(secondObj, "second");

  clock.tick(100);
  ok(original.calledOn(secondObj), "function is executed with the context of the call made after the timeout has passed");
  ok(original.calledWithExactly("second"), "function is executed with the param passed to the call made after the timeout has passed");
});
