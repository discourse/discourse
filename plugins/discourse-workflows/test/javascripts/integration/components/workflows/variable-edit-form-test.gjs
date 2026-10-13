import { tracked } from "@glimmer/tracking";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowVariableForm from "discourse/plugins/discourse-workflows/admin/components/workflows/variable-edit-form";

class TestWorkflow {
  @tracked variables;
  @tracked hasUnpublishedChanges;
  @tracked versionId;
  @tracked activeVersionId;

  constructor({
    id,
    variables = [],
    hasUnpublishedChanges = false,
    versionId = "draft-uuid",
    activeVersionId = "published-uuid",
  } = {}) {
    this.id = id;
    this.variables = variables;
    this.hasUnpublishedChanges = hasUnpublishedChanges;
    this.versionId = versionId;
    this.activeVersionId = activeVersionId;
  }

  setProperties(props) {
    Object.assign(this, props);
  }
}

module("Integration | Component | WorkflowVariableForm", function (hooks) {
  setupRenderingTest(hooks);

  test("has no label field", async function (assert) {
    const workflow = new TestWorkflow({ id: 1, variables: [] });

    await render(
      <template><WorkflowVariableForm @workflow={{workflow}} /></template>
    );

    assert.dom('input[name="label"]').doesNotExist();
  });

  test("create shows the choices editor for enum variables", async function (assert) {
    const workflow = new TestWorkflow({ id: 1, variables: [] });

    await render(
      <template><WorkflowVariableForm @workflow={{workflow}} /></template>
    );

    assert.dom(".simple-list").doesNotExist();

    await fillIn('select[name="variable_type"]', "enum");

    assert.dom(".simple-list").exists("shows the choices editor for enum");
  });

  test("edit pre-fills the form with the existing variable's values", async function (assert) {
    const workflow = new TestWorkflow({
      id: 1,
      variables: [
        {
          id: 10,
          key: "priority",
          label: "Priority",
          description: "How urgent",
          variable_type: "enum",
          type_options: { choices: ["low", "high"] },
        },
      ],
    });

    await render(
      <template>
        <WorkflowVariableForm @variableId="10" @workflow={{workflow}} />
      </template>
    );

    assert.dom('input[name="key"]').hasValue("priority");
    assert.dom('textarea[name="description"]').hasValue("How urgent");
    assert.dom(".simple-list").exists("shows the choices editor for enum");
  });

  test("duplicate key surfaces a validation error", async function (assert) {
    const workflow = new TestWorkflow({
      id: 1,
      variables: [
        { id: 10, key: "priority", label: "Priority", variable_type: "string" },
        { id: 11, key: "notes", label: "Notes", variable_type: "string" },
      ],
    });

    await render(
      <template>
        <WorkflowVariableForm @variableId="11" @workflow={{workflow}} />
      </template>
    );

    await fillIn('input[name="key"]', "priority");
    await click(".form-kit__button");

    assert
      .dom(".form-kit__errors")
      .exists("shows a validation error for the duplicate key");
  });

  test("malformed key surfaces a validation error", async function (assert) {
    const workflow = new TestWorkflow({ id: 1, variables: [] });

    await render(
      <template><WorkflowVariableForm @workflow={{workflow}} /></template>
    );

    await fillIn('input[name="key"]', "1notes");
    await click(".form-kit__button");

    assert
      .dom(".form-kit__errors")
      .exists("shows a validation error for the malformed key");
  });
});
