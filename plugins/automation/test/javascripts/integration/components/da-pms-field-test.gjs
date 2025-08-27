import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-pms-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "pms",
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await click(".insert-pm");

    await fillIn(".pm-title", "title");
    await fillIn(".d-editor-input", "raw");
    await fillIn(".pm-delay", 6);
    await click(".pm-prefers-encrypt", 6);

    assert.deepEqual(this.field.metadata.value, [
      {
        delay: "6",
        prefers_encrypt: false,
        raw: "raw",
        title: "title",
      },
    ]);
  });
});
