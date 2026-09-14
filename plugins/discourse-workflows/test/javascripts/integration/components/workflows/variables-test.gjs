import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowVariables from "discourse/plugins/discourse-workflows/admin/components/workflows/variables";

function buildWorkflow(overrides = {}) {
  return {
    id: 1,
    name: "Test workflow",
    versionId: "draft-uuid",
    activeVersionId: "published-uuid",
    hasUnpublishedChanges: false,
    variables: [],
    setProperties(props) {
      Object.assign(this, props);
    },
    ...overrides,
  };
}

module("Integration | Component | WorkflowVariables", function (hooks) {
  setupRenderingTest(hooks);

  test("escapes HTML in a variable's description before rendering it", async function (assert) {
    const workflow = buildWorkflow({
      variables: [
        {
          id: 10,
          key: "priority",
          label: "Priority",
          description: "<img src=x onerror=alert(1)>",
          variable_type: "string",
          type_options: {},
          value: "",
        },
      ],
    });

    await render(
      <template><WorkflowVariables @workflow={{workflow}} /></template>
    );

    assert
      .dom("[data-setting='priority'] img")
      .doesNotExist(
        "the description does not render as an executable <img> element"
      );
    assert
      .dom("[data-setting='priority'] .setting-value .desc")
      .includesText(
        "<img src=x onerror=alert(1)>",
        "the description renders as inert text"
      );
  });

  test("hides the publish notice when the workflow has no local variables", async function (assert) {
    const workflow = buildWorkflow({
      hasUnpublishedChanges: true,
      variables: [],
    });

    await render(
      <template><WorkflowVariables @workflow={{workflow}} /></template>
    );

    assert.dom(".workflows-variables-publish-notice").doesNotExist();
  });

  test("shows the publish notice when the workflow has local variables and pending changes", async function (assert) {
    const workflow = buildWorkflow({
      hasUnpublishedChanges: true,
      variables: [
        {
          id: 10,
          key: "priority",
          label: "Priority",
          description: "",
          variable_type: "string",
          type_options: {},
          value: "",
        },
      ],
    });

    await render(
      <template><WorkflowVariables @workflow={{workflow}} /></template>
    );

    assert.dom(".workflows-variables-publish-notice").exists();
  });
});
