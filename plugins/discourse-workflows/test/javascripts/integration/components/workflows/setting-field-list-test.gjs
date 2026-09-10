import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowSettingFieldList from "discourse/plugins/discourse-workflows/admin/components/workflows/setting-field-list";

module(
  "Integration | Component | Workflows | SettingFieldList",
  function (hooks) {
    setupRenderingTest(hooks);

    test("shows a single Manage fields link when fields exist", async function (assert) {
      const workflow = {
        id: 1,
        settingFields: [
          { id: 10, key: "priority", label: "Priority", field_type: "string" },
        ],
      };

      await render(
        <template><WorkflowSettingFieldList @workflow={{workflow}} /></template>
      );

      assert
        .dom(".workflows-settings__fields-manage")
        .exists({ count: 1 }, "renders exactly one entry point");
      assert.dom(".workflows-settings__fields-add").doesNotExist();
      assert.dom(".admin-config-area-empty-list").doesNotExist();
    });

    test("shows the empty-list CTA when there are no fields", async function (assert) {
      const workflow = { id: 1, settingFields: [] };

      await render(
        <template><WorkflowSettingFieldList @workflow={{workflow}} /></template>
      );

      assert.dom(".admin-config-area-empty-list").exists();
      assert.dom(".workflows-settings__fields-manage").doesNotExist();
    });

    test("empty-list CTA routes directly to the add-field form", async function (assert) {
      let transitionedTo;
      this.owner.lookup("service:router").transitionTo = (route) => {
        transitionedTo = route;
      };

      const workflow = { id: 1, settingFields: [] };

      await render(
        <template><WorkflowSettingFieldList @workflow={{workflow}} /></template>
      );

      await click(".admin-config-area-empty-list__cta-button");

      assert.strictEqual(
        transitionedTo,
        "adminPlugins.show.discourse-workflows.show.settings.fields.new",
        "routes straight to the new-field form, not the (also empty) fields index"
      );
    });
  }
);
