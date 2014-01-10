module("Discourse");
var store = Discourse.KeyValueStore;

test("knows if it's in focus", function() {
  ok(Discourse.get('hasFocus'));
  $(window).triggerHandler('blur')
  ok(!Discourse.get('hasFocus'));
  $(window).triggerHandler('focus');
  ok(Discourse.get('hasFocus'));
});

test("knows whether it is the last active instance", function(){
  expect(3);
  ok(Discourse.get('isLastActiveInstance'));

  // emulate other window getting active
  $(window).triggerHandler('blur');
  window.onstorage && window.onstorage({
    key: 'discourse_lastActiveInstance',
    oldValue: store.get('lastActiveInstance'),
    newValue: 'i_am_the_id_of_another_window'
  });
  ok(!Discourse.get('isLastActiveInstance'));
  
  $(window).triggerHandler('focus');
  ok(Discourse.get('isLastActiveInstance'));
});
