/*global module:true test:true ok:true visit:true equal:true exists:true count:true equal:true present:true md5:true */

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
