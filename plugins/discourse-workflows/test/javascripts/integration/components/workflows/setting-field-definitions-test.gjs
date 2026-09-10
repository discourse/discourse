import { tracked } from "@glimmer/tracking";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowSettingFieldDefinitions from "discourse/plugins/discourse-workflows/admin/components/workflows/setting-field-definitions";

class TestWorkflow {
  @tracked settingFields;
  @tracked hasUnpublishedChanges;
  @tracked versionId;
  @tracked activeVersionId;

  constructor({
    id,
    settingFields = [],
    hasUnpublishedChanges = false,
    versionId = "draft-uuid",
    activeVersionId = "published-uuid",
  } = {}) {
    this.id = id;
    this.settingFields = settingFields;
    this.hasUnpublishedChanges = hasUnpublishedChanges;
    this.versionId = versionId;
    this.activeVersionId = activeVersionId;
  }

  setProperties(props) {
    Object.assign(this, props);
  }
}

module(
  "Integration | Component | Workflows | SettingFieldDefinitions",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders existing field definitions", async function (assert) {
      const workflow = new TestWorkflow({
        id: 1,
        settingFields: [
          { id: 10, key: "priority", label: "Priority", field_type: "string" },
        ],
      });

      await render(
        <template>
          <WorkflowSettingFieldDefinitions @workflow={{workflow}} />
        </template>
      );

      assert.dom(".d-table__overview-name").hasText("Priority");
      assert.dom(".workflows-setting-field-key").hasText("priority");
      assert.dom(".workflows-setting-fields-table__type").hasText("String");
    });

    test("edit navigates to the dedicated edit route instead of expanding inline", async function (assert) {
      let transitionedTo;
      this.owner.lookup("service:router").transitionTo = (route, ...models) => {
        transitionedTo = { route, models };
      };

      const workflow = new TestWorkflow({
        id: 1,
        settingFields: [
          { id: 10, key: "priority", label: "Priority", field_type: "string" },
        ],
      });

      await render(
        <template>
          <WorkflowSettingFieldDefinitions @workflow={{workflow}} />
        </template>
      );

      await click(".workflows-setting-fields-table__edit");

      assert.deepEqual(transitionedTo, {
        route:
          "adminPlugins.show.discourse-workflows.show.settings.fields.edit",
        models: [10],
      });
    });

    test("add field navigates to the dedicated new route instead of expanding inline", async function (assert) {
      let transitionedTo;
      this.owner.lookup("service:router").transitionTo = (route) => {
        transitionedTo = route;
      };

      const workflow = new TestWorkflow({
        id: 1,
        settingFields: [
          { id: 10, key: "priority", label: "Priority", field_type: "string" },
        ],
      });

      await render(
        <template>
          <WorkflowSettingFieldDefinitions @workflow={{workflow}} />
        </template>
      );

      await click(".workflows-settings__fields-add");

      assert.strictEqual(
        transitionedTo,
        "adminPlugins.show.discourse-workflows.show.settings.fields.new"
      );
    });

    test("empty state CTA navigates to the dedicated new route", async function (assert) {
      let transitionedTo;
      this.owner.lookup("service:router").transitionTo = (route) => {
        transitionedTo = route;
      };

      const workflow = new TestWorkflow({ id: 1, settingFields: [] });

      await render(
        <template>
          <WorkflowSettingFieldDefinitions @workflow={{workflow}} />
        </template>
      );

      await click(".admin-config-area-empty-list__cta-button");

      assert.strictEqual(
        transitionedTo,
        "adminPlugins.show.discourse-workflows.show.settings.fields.new"
      );
    });
  }
);
