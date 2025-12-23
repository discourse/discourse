import { getOwner } from "@ember/owner";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-relative_time-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "relative_time",
    });

    await render(
      <template>
        <AutomationField
          @automation={{this.automation}}
          @field={{this.field}}
        />
      </template>
    );

    await fillIn(".relative-time-duration", "4");
    assert.strictEqual(this.field.metadata.value, 4);

    await selectKit().expand();
    await selectKit().selectRowByValue("hours");

    assert.strictEqual(this.field.metadata.value, 4 * 60);
  });
});
