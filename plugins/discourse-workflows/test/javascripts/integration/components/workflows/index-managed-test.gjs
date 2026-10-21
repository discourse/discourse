import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import WorkflowsIndex from "discourse/plugins/discourse-workflows/admin/components/workflows/index";

module(
  "Integration | Component | WorkflowsIndex managed sections",
  function (hooks) {
    setupRenderingTest(hooks);

    test("groups workflows by plugin below regular workflows", async function (assert) {
      this.workflows = {
        totalRows: 5,
        canLoadMore: false,
        content: [
          {
            id: 1,
            name: "Managed sync",
            tags: [],
            managed_by: { name: "Example" },
          },
          { id: 2, name: "My automation", tags: [] },
          { id: 3, name: "Editable copy", tags: [], managed_by: null },
          {
            id: 4,
            name: "Another sync",
            tags: [],
            managed_by: { name: "Example" },
          },
          {
            id: 5,
            name: "Other integration",
            tags: [],
            managed_by: { name: "Another" },
          },
        ],
      };
      await render(
        <template><WorkflowsIndex @workflows={{this.workflows}} /></template>
      );
      assert.deepEqual(
        findAll("[data-test-workflow-section]").map(
          (element) => element.dataset.testWorkflowSection
        ),
        ["regular", "managed:Another", "managed:Example"]
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
        .dom('[data-test-workflow-section="managed:Example"]')
        .includesText("Managed sync");
      assert
        .dom('[data-test-workflow-section="managed:Example"]')
        .doesNotIncludeText("My automation");
      assert.deepEqual(
        findAll(".workflows-index__section-heading h2").map((element) =>
          element.textContent.trim()
        ),
        ["Another plugin", "Example plugin"]
      );
      assert
        .dom('[data-test-workflow-section="managed:Example"]')
        .includesText("Another sync");
      assert
        .dom('[data-test-workflow-section="managed:Example"]')
        .doesNotIncludeText("Other integration");
      assert
        .dom('[data-test-workflow-section="managed:Another"]')
        .includesText("Other integration");
      assert.dom("[data-test-workflow-owner]").doesNotExist();
      assert
        .dom(".workflows-index__section-heading")
        .includesText("These workflows are read-only.");
      assert
        .dom(".workflows-index__section-heading")
        .includesText("duplicate a workflow to create an editable copy");
    });
  }
);
