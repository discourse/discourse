import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import notificationsTracking from "discourse/tests/helpers/notifications-tracking-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module(
  "Integration | Component | da-category-notification-level-field",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.automation = new AutomationFabricators(getOwner(this)).automation();
    });

    test("set value", async function (assert) {
      const self = this;

      this.field = new AutomationFabricators(getOwner(this)).field({
        component: "category_notification_level",
      });

      await render(
        <template>
          <AutomationField
            @automation={{self.automation}}
            @field={{self.field}}
          />
        </template>
      );
      await notificationsTracking().selectLevelId(2);

      assert.strictEqual(this.field.metadata.value, 2);
    });
  }
);
