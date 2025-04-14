import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-boolean-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field();

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );
    await click("input");

    assert.dom("input").isChecked();
    assert.true(this.field.metadata.value);
  });
});
