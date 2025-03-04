import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import FlatButton from "discourse/components/flat-button";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | flat-button", function (hooks) {
  setupRenderingTest(hooks);

  test("press Enter", async function (assert) {
    const self = this;

    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(<template><FlatButton @action={{self.action}} /></template>);

    await triggerKeyEvent(".btn-flat", "keydown", "Space");
    assert.strictEqual(this.foo, null);

    await triggerKeyEvent(".btn-flat", "keydown", "Enter");
    assert.strictEqual(this.foo, "bar");
  });

  test("click", async function (assert) {
    const self = this;

    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(<template><FlatButton @action={{self.action}} /></template>);

    await click(".btn-flat");
    assert.strictEqual(this.foo, "bar");
  });
});
