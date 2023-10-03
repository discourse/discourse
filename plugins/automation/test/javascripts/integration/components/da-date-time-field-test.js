import { module, test } from "qunit";
import { hbs } from "ember-cli-htmlbars";
import { fillIn, render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import fabricators from "discourse/plugins/discourse-automation/discourse/lib/fabricators";

module("Integration | Component | da-date-time-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = fabricators.automation();
  });

  test("set value", async function (assert) {
    this.field = fabricators.field({ component: "date_time" });

    await render(
      hbs`<AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );
    await fillIn("input", "2023-10-03T12:34");

    assert.ok(this.field.metadata.value !== null);
  });
});
