import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowSettings from "discourse/plugins/discourse-workflows/admin/components/workflows/settings";

function buildWorkflow(overrides = {}) {
  return {
    id: 1,
    name: "Test workflow",
    errorWorkflowId: null,
    errorWorkflowName: null,
    timezone: "UTC",
    versionId: "draft-uuid",
    activeVersionId: "published-uuid",
    hasUnpublishedChanges: false,
    settingFields: [],
    setProperties(props) {
      Object.assign(this, props);
    },
    ...overrides,
  };
}

module("Integration | Component | Workflows | Settings", function (hooks) {
  setupRenderingTest(hooks);

  test("escapes HTML in a field's description before rendering it", async function (assert) {
    const workflow = buildWorkflow({
      settingFields: [
        {
          id: 10,
          key: "priority",
          label: "Priority",
          description: "<img src=x onerror=alert(1)>",
          field_type: "string",
          type_options: {},
          value: "",
        },
      ],
    });

    await render(
      <template><WorkflowSettings @workflow={{workflow}} /></template>
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
});
