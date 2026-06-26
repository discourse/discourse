import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ExecutionDetail from "discourse/plugins/discourse-workflows/admin/components/workflows/executions/detail";

let transitions;

class RouterStub extends Service {
  transitionTo(...args) {
    transitions.push(args);
  }
}

class WorkflowsNodeTypesStub extends Service {
  nodeTypes = [];

  load() {}

  findNodeType() {
    return null;
  }
}

module(
  "Integration | Component | Workflows | Executions | ExecutionDetail",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      transitions = [];

      this.owner.unregister("service:router");
      this.owner.register("service:router", RouterStub);
      this.owner.unregister("service:workflows-node-types");
      this.owner.register(
        "service:workflows-node-types",
        WorkflowsNodeTypesStub
      );
    });

    test("opens workflow call child executions through the admin route", async function (assert) {
      this.execution = {
        id: 11471,
        workflow_id: 30,
        workflow_name: "Parent workflow",
        status: "success",
        started_at: "2026-06-24T10:00:00Z",
        finished_at: "2026-06-24T10:00:01Z",
        steps: [
          {
            node_id: "call-1",
            node_name: "Call workflow",
            node_type: "action:workflow_call",
            status: "success",
            input: [],
            output: [],
            metadata: {
              operation: "run",
            },
            started_at: "2026-06-24T10:00:00Z",
            finished_at: "2026-06-24T10:00:01Z",
            workflow_call_run: {
              run_id: 1,
              workflow_id: 31,
              workflow_name: "Child workflow",
              execution_id: 11472,
              execution_url:
                "https://example.com/admin/plugins/discourse-workflows/workflows/31/executions/11472",
              status: "success",
            },
          },
        ],
      };

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );

      assert
        .dom(".workflows-execution-detail__workflow-call-link")
        .exists("the open execution button renders");
      assert
        .dom(".workflows-execution-detail__workflow-call-link")
        .doesNotHaveAttribute("href", "the button does not force a page load");

      await click(".workflows-execution-detail__workflow-call-link");

      assert.deepEqual(
        transitions,
        [
          [
            "adminPlugins.show.discourse-workflows.show.executions.show",
            31,
            11472,
          ],
        ],
        "the button transitions to the child execution route"
      );
    });

    test("opens parent workflow executions through the admin route", async function (assert) {
      this.execution = {
        id: 11472,
        workflow_id: 31,
        workflow_name: "Child workflow",
        workflow_call_caller: {
          workflow_id: 30,
          workflow_name: "Parent workflow",
          execution_id: 11471,
          execution_url:
            "https://example.com/admin/plugins/discourse-workflows/workflows/30/executions/11471",
          node_id: "call-1",
          node_name: "Call child workflow",
          node_type: "action:workflow_call",
        },
        status: "success",
        started_at: "2026-06-24T10:00:00Z",
        finished_at: "2026-06-24T10:00:01Z",
        steps: [],
      };

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );

      assert
        .dom(".workflows-execution-detail__workflow-call.--caller")
        .hasText(
          "Called by Parent workflow Open parent execution",
          "the compact parent execution row renders"
        );
      assert
        .dom(".workflows-execution-detail__workflow-call-parent-link")
        .doesNotHaveAttribute("href", "the button does not force a page load");

      await click(".workflows-execution-detail__workflow-call-parent-link");

      assert.deepEqual(
        transitions,
        [
          [
            "adminPlugins.show.discourse-workflows.show.executions.show",
            30,
            11471,
          ],
        ],
        "the button transitions to the parent execution route"
      );
    });
  }
);
