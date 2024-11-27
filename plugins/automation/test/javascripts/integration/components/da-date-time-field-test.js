import { getOwner } from "@ember/owner";
import { fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-date-time-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "date_time",
    });

    await render(
      hbs`<AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );
    await fillIn("input", "2023-10-03T12:34");

    assert.notStrictEqual(this.field.metadata.value, null);
  });
});
