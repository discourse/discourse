import { tracked } from "@glimmer/tracking";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowSettingFieldForm from "discourse/plugins/discourse-workflows/admin/components/workflows/setting-field-edit-form";

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
  "Integration | Component | Workflows | SettingFieldForm",
  function (hooks) {
    setupRenderingTest(hooks);

    test("create shows the choices editor for enum fields", async function (assert) {
      const workflow = new TestWorkflow({ id: 1, settingFields: [] });

      await render(
        <template><WorkflowSettingFieldForm @workflow={{workflow}} /></template>
      );

      assert.dom(".simple-list").doesNotExist();

      await fillIn('select[name="field_type"]', "enum");

      assert.dom(".simple-list").exists("shows the choices editor for enum");
    });

    test("edit pre-fills the form with the existing field's values", async function (assert) {
      const workflow = new TestWorkflow({
        id: 1,
        settingFields: [
          {
            id: 10,
            key: "priority",
            label: "Priority",
            description: "How urgent",
            field_type: "enum",
            type_options: { choices: ["low", "high"] },
          },
        ],
      });

      await render(
        <template>
          <WorkflowSettingFieldForm @fieldId="10" @workflow={{workflow}} />
        </template>
      );

      assert.dom('input[name="label"]').hasValue("Priority");
      assert.dom('input[name="key"]').hasValue("priority");
      assert.dom(".simple-list").exists("shows the choices editor for enum");
    });

    test("duplicate key surfaces a validation error", async function (assert) {
      const workflow = new TestWorkflow({
        id: 1,
        settingFields: [
          { id: 10, key: "priority", label: "Priority", field_type: "string" },
          { id: 11, key: "notes", label: "Notes", field_type: "string" },
        ],
      });

      await render(
        <template>
          <WorkflowSettingFieldForm @fieldId="11" @workflow={{workflow}} />
        </template>
      );

      await fillIn('input[name="key"]', "priority");
      await click(".form-kit__button");

      assert
        .dom(".form-kit__errors")
        .exists("shows a validation error for the duplicate key");
    });

    test("malformed key surfaces a validation error", async function (assert) {
      const workflow = new TestWorkflow({ id: 1, settingFields: [] });

      await render(
        <template><WorkflowSettingFieldForm @workflow={{workflow}} /></template>
      );

      await fillIn('input[name="label"]', "Notes");
      await fillIn('input[name="key"]', "1notes");
      await click(".form-kit__button");

      assert
        .dom(".form-kit__errors")
        .exists("shows a validation error for the malformed key");
    });
  }
);
