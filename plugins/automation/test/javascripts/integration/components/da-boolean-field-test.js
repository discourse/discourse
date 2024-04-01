import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/discourse-automation/discourse/lib/fabricators";

module("Integration | Component | da-boolean-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = fabricators.automation();
  });

  test("set value", async function (assert) {
    this.field = fabricators.field();

    await render(
      hbs`<AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );
    await click("input");

    assert.dom("input").isChecked();
    assert.strictEqual(this.field.metadata.value, true);
  });
});
