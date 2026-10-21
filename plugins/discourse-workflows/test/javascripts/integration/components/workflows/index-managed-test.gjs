import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowsIndex from "discourse/plugins/discourse-workflows/admin/components/workflows/index";

module(
  "Integration | Component | WorkflowsIndex managed sections",
  function (hooks) {
    setupRenderingTest(hooks);

    test("separates plugin-owned workflows below regular workflows", async function (assert) {
      this.workflows = {
        totalRows: 3,
        canLoadMore: false,
        content: [
          {
            id: 1,
            name: "Managed sync",
            tags: [],
            managed_by: { name: "Example plugin" },
          },
          { id: 2, name: "My automation", tags: [] },
          { id: 3, name: "Editable copy", tags: [], managed_by: null },
        ],
      };
      await render(
        <template><WorkflowsIndex @workflows={{this.workflows}} /></template>
      );
      assert.deepEqual(
        findAll("[data-test-workflow-section]").map(
          (element) => element.dataset.testWorkflowSection
        ),
        ["regular", "managed"]
      );
      assert
        .dom('[data-test-workflow-section="regular"]')
        .includesText("My automation");
      assert
        .dom('[data-test-workflow-section="regular"]')
        .includesText("Editable copy");
      assert
        .dom('[data-test-workflow-section="regular"]')
        .doesNotIncludeText("Managed sync");
      assert
        .dom('[data-test-workflow-section="managed"]')
        .includesText("Managed sync");
      assert
        .dom('[data-test-workflow-section="managed"]')
        .doesNotIncludeText("My automation");
      assert
        .dom('[data-test-workflow-owner="1"]')
        .includesText("Managed by Example plugin");
    });
  }
);
