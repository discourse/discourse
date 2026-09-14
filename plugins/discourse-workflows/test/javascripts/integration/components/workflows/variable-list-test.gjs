import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowVariableList from "discourse/plugins/discourse-workflows/admin/components/workflows/variable-list";

module("Integration | Component | WorkflowVariableList", function (hooks) {
  setupRenderingTest(hooks);

  test("shows a single Manage variables link when variables exist", async function (assert) {
    const workflow = {
      id: 1,
      variables: [
        { id: 10, key: "priority", label: "Priority", variable_type: "string" },
      ],
    };

    await render(
      <template><WorkflowVariableList @workflow={{workflow}} /></template>
    );

    assert
      .dom(".workflows-variables__manage")
      .exists({ count: 1 }, "renders exactly one entry point");
    assert.dom(".workflows-variables__add").doesNotExist();
    assert.dom(".admin-config-area-empty-list").doesNotExist();
  });

  test("shows the empty-list CTA when there are no variables", async function (assert) {
    const workflow = { id: 1, variables: [] };

    await render(
      <template><WorkflowVariableList @workflow={{workflow}} /></template>
    );

    assert.dom(".admin-config-area-empty-list").exists();
    assert.dom(".workflows-variables__manage").doesNotExist();
  });

  test("empty-list CTA routes directly to the add-variable form", async function (assert) {
    let transitionedTo;
    this.owner.lookup("service:router").transitionTo = (route) => {
      transitionedTo = route;
    };

    const workflow = { id: 1, variables: [] };

    await render(
      <template><WorkflowVariableList @workflow={{workflow}} /></template>
    );

    await click(".admin-config-area-empty-list__cta-button");

    assert.strictEqual(
      transitionedTo,
      "adminPlugins.show.discourse-workflows.show.variables.new",
      "routes straight to the new-variable form, not the (also empty) manage page"
    );
  });
});
