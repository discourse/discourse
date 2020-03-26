import KeyValueStore from "discourse/lib/key-value-store";

QUnit.module("lib:key-value-store");

QUnit.test("it's able to get the result back from the store", assert => {
  const store = new KeyValueStore("_test");
  store.set({ key: "bob", value: "uncle" });
  assert.equal(store.get("bob"), "uncle");
});

QUnit.test("is able to nuke the store", assert => {
  const store = new KeyValueStore("_test");
  store.set({ key: "bob1", value: "uncle" });
  store.abandonLocal();
  localStorage.a = 1;
  assert.equal(store.get("bob1"), void 0);
  assert.equal(localStorage.a, "1");
});
