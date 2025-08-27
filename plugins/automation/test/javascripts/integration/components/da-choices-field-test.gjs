import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-choices-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "choices",
      extra: { content: [{ name: "One", id: 1 }] },
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue(1);

    assert.strictEqual(this.field.metadata.value, 1);
  });

  test("empty multiselect", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "choices",
      extra: { multiselect: true, content: [{ name: "One", id: 1 }] },
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue(1);

    assert.deepEqual(this.field.metadata.value, [1]);

    await selectKit().deselectItemByValue(1);

    assert.strictEqual(this.field.metadata.value, undefined);
  });
});
