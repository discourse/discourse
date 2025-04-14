import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-choices-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "choices",
      extra: { content: [{ name: "One", id: 1 }] },
    });

    await render(
      hbs` <AutomationField @automation={{this.automation}} @field={{this.field}} />`
    );

    await selectKit().expand();
    await selectKit().selectRowByValue(1);

    assert.strictEqual(this.field.metadata.value, 1);
  });
});
