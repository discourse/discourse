import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";

module("Unit | Utility | key-value-store", function () {
  test("it's able to get the result back from the store", function (assert) {
    const store = new KeyValueStore("_test");
    store.set({ key: "bob", value: "uncle" });
    assert.strictEqual(store.get("bob"), "uncle");
  });

  test("is able to nuke the store", function (assert) {
    const store = new KeyValueStore("_test");
    store.set({ key: "bob1", value: "uncle" });
    store.abandonLocal();
    localStorage.a = 1;
    assert.strictEqual(store.get("bob1"), void 0);
    assert.strictEqual(localStorage.a, "1");
  });
});
