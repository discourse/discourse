import { assert, module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Helper | if-action", function (hooks) {
  setupRenderingTest(hooks);

  test("The action exists", async function () {
    this.set("value", null);
    this.set("action", () => this.set("value", "foo"));
    await render(hbs`<DButton @action={{if-action this.action}} />`);
    await click("button");

    assert.equal(this.value, "foo");
  });

  test("The action doesn’t exist", async function () {
    await render(hbs`<DButton @action={{if-action this.action}} />`);
    await click("button");

    assert.ok(true, "it didn't raise an error");
  });
});
