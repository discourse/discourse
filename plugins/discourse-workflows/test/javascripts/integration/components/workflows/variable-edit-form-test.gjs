import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { moveVia } from "discourse/tests/helpers/ui-kit/reorderable-list-helper";
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

  // TODO (ui-kit-reorderable-list-cleanup) fold this over the choices tests
  // above once `enable_new_reordering_controls` ships.
  test("with the new reordering controls, a moved choice is saved in its new place", async function (assert) {
    getOwner(this).lookup(
      "service:site-settings"
    ).enable_new_reordering_controls = true;
    sinon.stub(getOwner(this).lookup("service:router"), "transitionTo");

    const variable = {
      id: 10,
      key: "priority",
      variable_type: "enum",
      type_options: { choices: ["low", "medium", "high"] },
    };
    const workflow = new TestWorkflow({ id: 1, variables: [variable] });

    let savedChoices;
    pretender.put(
      "/admin/plugins/discourse-workflows/workflows/1/variables/10.json",
      (request) => {
        savedChoices = new URLSearchParams(request.requestBody).getAll(
          "type_options[choices][]"
        );
        return response({
          variable,
          workflow: {
            version_id: "draft-uuid",
            active_version_id: "published-uuid",
            has_unpublished_changes: true,
          },
        });
      }
    );

    await render(
      <template>
        <DMenus />
        <WorkflowVariableForm @variableId="10" @workflow={{workflow}} />
      </template>
    );

    assert
      .dom(".simple-list .d-reorderable-list__handle")
      .exists({ count: 3 }, "each choice has the shared reorder handle");

    await moveVia("2", "top", ".simple-list");
    await click(".form-kit__button");

    assert.deepEqual(
      savedChoices,
      ["high", "low", "medium"],
      "the choices are saved in the order shown"
    );
  });
});
