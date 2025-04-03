import { getOwner } from "@ember/owner";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";
import AutomationField from "discourse/plugins/chat/admin/components/automation-field";

module("Integration | Component | da-post-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();
  });

  test("set value", async function (assert) {const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "post",
    });

    await render(
      <template><AutomationField @automation={{self.automation}} @field={{self.field}} /></template>
    );
    await fillIn("textarea", "Hello World");

    assert.strictEqual(this.field.metadata.value, "Hello World");
  });
});
