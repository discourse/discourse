var clock, original, debounced;

var firedOnce = function(message) {
  ok(original.calledOnce, message);
};

var firedTwice = function(message) {
  ok(original.calledTwice, message);
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

test("prolongs the timeout when the debounced function is called for the second time during the timeout", function() {
  debounced();

  clock.tick(50);
  debounced();

  clock.tick(50);
  notFired("at the end of the original timeout nothing happens");

  clock.tick(50);
  firedOnce("function is executed exactly at the end of the prolonged timeout");
});

test("preserves last call's context and params when executing delayed function", function() {
  var firstObj = {};
  var secondObj = {};

  debounced.call(firstObj, "first");
  debounced.call(secondObj, "second");

  clock.tick(100);
  ok(original.calledOn(secondObj), "the context of the last of two subsequent calls is preserved");
  ok(original.calledWithExactly("second"), "param passed during the last of two subsequent calls is preserved");
});

test("can be called again after timeout passes", function() {
  var firstObj = {};
  var secondObj = {};

  debounced.call(firstObj, "first");

  clock.tick(100);
  debounced.call(secondObj, "second");

  clock.tick(100);
  firedTwice();
});
