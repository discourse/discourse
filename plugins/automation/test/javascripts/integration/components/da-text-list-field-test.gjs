import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-text-list-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "text_list",
    });

    await render(
      <template>
        <AutomationField
          @automation={{this.automation}}
          @field={{this.field}}
        />
      </template>
    );
    await selectKit().expand();
    await selectKit().fillInFilter("test");
    await selectKit().selectRowByValue("test");

    assert.deepEqual(this.field.metadata.value, ["test"]);
  });
});
