import { module, test } from "qunit";
import KeyValueStore from "discourse/lib/key-value-store";

module("Unit | Utility | key-value-store", function () {
  test("is able to get the result back from the store", function (assert) {
    const store = new KeyValueStore("example");
    store.set({ key: "bob", value: "uncle" });

    assert.strictEqual(store.get("bob"), "uncle");
  });

  test("is able remove items from the store", function (assert) {
    const store = new KeyValueStore("example");
    store.set({ key: "bob", value: "uncle" });
    store.remove("bob");

    assert.strictEqual(store.get("bob"), undefined);
  });

  test("is able to remove multiple items at once from the store", function (assert) {
    const store = new KeyValueStore("example");
    store.set({ key: "bob", value: "uncle" });
    store.set({ key: "jane", value: "sister" });
    store.set({ key: "clark", value: "brother" });

    store.removeKeys((key, value) => {
      return key.includes("bob") || value === "brother";
    });

    assert.strictEqual(store.get("bob"), undefined);
    assert.strictEqual(store.get("jane"), "sister");
    assert.strictEqual(store.get("clark"), undefined);
  });

  test("is able to nuke the store", function (assert) {
    const store = new KeyValueStore("example");
    store.set({ key: "bob1", value: "uncle" });
    store.abandonLocal();
    localStorage.a = 1;

    assert.strictEqual(store.get("bob1"), undefined);
    assert.strictEqual(localStorage.a, "1");
  });

  test("is API-compatible with `localStorage`", function (assert) {
    const store = new KeyValueStore("example");
    store.setItem("bob", "uncle");
    assert.strictEqual(store.getItem("bob"), "uncle");

    store.removeItem("bob");
    assert.strictEqual(store.getItem("bob"), undefined);
  });
});
