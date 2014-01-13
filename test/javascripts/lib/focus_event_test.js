module("Discourse");
var store = Discourse.KeyValueStore;

test("knows if it's in focus", function() {
  ok(Discourse.get('hasFocus'), 'first focus should be true');
  $(window).triggerHandler('blur');
  ok(!Discourse.get('hasFocus'), 'after blur, focus should be false');
  $(window).triggerHandler('focus');
  ok(Discourse.get('hasFocus'), 'after focus, focus should be true');
});

test("knows whether it is the last active instance", function(){
  ok(Discourse.get('isLastActiveInstance'));

  // emulate other window getting active
  $(window).triggerHandler('blur');
  equal(typeof(window.onstorage), 'function');
  window.onstorage({
    key: 'discourse_lastActiveInstance',
    oldValue: store.get('lastActiveInstance'),
    newValue: 'i_am_the_id_of_another_window'
  });
  ok(!Discourse.get('isLastActiveInstance'));

  $(window).triggerHandler('focus');
  ok(Discourse.get('isLastActiveInstance'));
});
