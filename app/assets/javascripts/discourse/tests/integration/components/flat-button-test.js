import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | flat-button", function (hooks) {
  setupRenderingTest(hooks);

  test("press Enter", async function (assert) {
    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(hbs`<FlatButton @action={{this.action}} />`);

    await triggerKeyEvent(".btn-flat", "keydown", "Space");
    assert.strictEqual(this.foo, null);

    await triggerKeyEvent(".btn-flat", "keydown", "Enter");
    assert.strictEqual(this.foo, "bar");
  });

  test("click", async function (assert) {
    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(hbs`<FlatButton @action={{this.action}} />`);

    await click(".btn-flat");
    assert.strictEqual(this.foo, "bar");
  });
});
