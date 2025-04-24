import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SessionStore from "discourse/lib/session-store";

module("Unit | Utility | session-store", function (hooks) {
  setupTest(hooks);

  test("is able to get the result back from the store", function (assert) {
    const store = new SessionStore("example");
    store.set({ key: "bob", value: "uncle" });

    assert.strictEqual(store.get("bob"), "uncle");
  });

  test("is able remove items from the store", function (assert) {
    const store = new SessionStore("example");
    store.set({ key: "bob", value: "uncle" });
    store.remove("bob");

    assert.strictEqual(store.get("bob"), null);
  });

  test("is able to remove multiple items at once from the store", function (assert) {
    const store = new SessionStore("example");
    store.set({ key: "bob", value: "uncle" });
    store.set({ key: "jane", value: "sister" });
    store.set({ key: "clark", value: "brother" });

    store.removeKeys((key, value) => {
      return key.includes("bob") || value === "brother";
    });

    assert.strictEqual(store.get("bob"), null);
    assert.strictEqual(store.get("jane"), "sister");
    assert.strictEqual(store.get("clark"), null);
  });

  test("is able to nuke the store", function (assert) {
    const store = new SessionStore("example");
    store.set({ key: "bob1", value: "uncle" });
    store.abandonLocal();
    sessionStorage.setItem("a", 1);

    assert.strictEqual(store.get("bob1"), null);
    assert.strictEqual(sessionStorage.getItem("a"), "1");
  });

  test("is API-compatible with `sessionStorage`", function (assert) {
    const store = new SessionStore("example");
    store.setItem("bob", "uncle");
    assert.strictEqual(store.getItem("bob"), "uncle");

    store.removeItem("bob");
    assert.strictEqual(store.getItem("bob"), null);
  });
});
