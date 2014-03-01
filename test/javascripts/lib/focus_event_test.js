var store = Discourse.KeyValueStore;

module("Discourse.KeyValueStore", {
  setup: function() {
    Discourse.runInitializers();
    store.init("test");
  }
});

// these don't work in phantomjs.
//TODO rewrite focus events to use ember computed properties for testability.
var blurTest = function() {
  jQuery.event.dispatch(jQuery.Event("blur"));
};
var focusTest = function() {

  jQuery.event.dispatch(jQuery.Event("focus"));
};

test("needs KeyValueStore to be initialized properly", function(){
  ok(store.initialized, "KeyValueStore is not initialized.");
  ok(store.listeners.lastActiveInstance !== undefined &&
    typeof(store.listeners.lastActiveInstance[0] === 'function'),
    "isLastActiveInstance event is not registered.");
});

test("knows if it's in focus", function() {
  ok(Discourse.get('hasFocus'), 'first focus should be true');
  blurTest();
  ok(!Discourse.get('hasFocus'), 'after blur, focus should be false');
  focusTest();
  ok(Discourse.get('hasFocus'), 'after focus, focus should be true');
});

test("knows whether it is the last active instance", function(){
  ok(Discourse.get('isLastActiveInstance'));

  // emulate other window getting active
  blurTest();
  if(typeof(window.onstorage) !== 'function') {
    ok(false, "window.onstorage is not a function!");
  }
  Discourse.KeyValueStore.handleStorageEvent({
    key: 'discourse_lastActiveInstance',
    oldValue: store.get('lastActiveInstance'),
    newValue: 'i_am_the_id_of_another_window'
  });
  ok(!Discourse.get('isLastActiveInstance'),
    'after another window gets active, isLastActiveInstance should be false');

  focusTest();
  ok(Discourse.get('isLastActiveInstance'), 'after focus, isLastActiveInstance should be true');
});
