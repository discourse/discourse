import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | Toasts", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.toasts = getOwner(this).lookup("service:toasts");
  });

  test("views option", async function (assert) {
    this.toasts.show({ views: ["desktop"], data: { text: "foo" } });

    assert.deepEqual(this.toasts.activeToasts.length, 1);

    this.toasts.show({ views: ["mobile"], data: { text: "foo" } });

    assert.true(this.toasts.activeToasts.length < 2);
  });

  test("key option replaces the toast sharing that key", function (assert) {
    this.toasts.show({ key: "penalty", data: { text: "first" } });
    this.toasts.show({ key: "other", data: { text: "untouched" } });
    this.toasts.show({ key: "penalty", data: { text: "second" } });

    assert.deepEqual(
      this.toasts.activeToasts.map((toast) => toast.options.data.text),
      ["untouched", "second"]
    );
  });

  test("toasts without a key stack", function (assert) {
    this.toasts.show({ data: { text: "first" } });
    this.toasts.show({ data: { text: "second" } });

    assert.strictEqual(this.toasts.activeToasts.length, 2);
  });
});
