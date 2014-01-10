var store = Discourse.KeyValueStore;

module("Discourse.KeyValueStore", {
  setup: function() {
    store.init("test");
  }
});

test("it's able to get the result back from the store", function() {
  store.set({ key: "bob", value: "uncle" });
  equal(store.get("bob"), "uncle");
});

test("is able to nuke the store", function() {
  store.set({ key: "bob1", value: "uncle" });
  store.abandonLocal();
  localStorage.a = 1;
  equal(store.get("bob1"), void 0);
  equal(localStorage.a, "1");
});

test("can listen on browser events", function() {
  expect(3);
  var gotten = false;
  var storageKey = "test", oldValue = "oldValue", newValue = "newValue";
  store.set({key: storageKey, value: oldValue});

  store.listen(storageKey, function(oldArg, newArg){
    equal(oldArg, oldValue);
    equal(newArg, newValue);
    gotten = true;
  });

  // emulate event in different window
  window.onstorage && window.onstorage({
    key: store.context+storageKey,
    oldValue: oldValue,
    newValue: newValue});

  ok(gotten);
});
