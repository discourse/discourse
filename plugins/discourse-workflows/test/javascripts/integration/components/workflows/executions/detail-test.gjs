import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { publishToMessageBus } from "discourse/tests/helpers/qunit-helpers";
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

class ReplayMessageBusStub extends Service {
  subscribe(channel, handler, lastId) {
    if (lastId === 0) {
      handler({
        type: "execution_progress",
        execution: { id: 11474, status: "running" },
        refresh: false,
        step: {
          node_id: "node-1",
          node_name: "Already running",
          node_type: "action:code",
          position: 0,
          status: "running",
          started_at: new Date().toISOString(),
          finished_at: null,
        },
      });
    }
  }

  unsubscribe() {}
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
    test("replays progress emitted before the detail page subscribes", async function (assert) {
      this.owner.unregister("service:message-bus");
      this.owner.register("service:message-bus", ReplayMessageBusStub);
      this.execution = {
        id: 11474,
        workflow_id: 30,
        workflow_name: "Running workflow",
        status: "running",
        started_at: new Date().toISOString(),
        finished_at: null,
        steps: [],
      };

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );

      assert
        .dom(".workflows-execution-detail__step-name")
        .hasText(
          "Already running",
          "a step emitted before navigation is restored from the channel backlog"
        );
    });

    test("refreshes authoritative details at a terminal boundary", async function (assert) {
      this.execution = {
        id: 11475,
        workflow_id: 30,
        workflow_name: "Running workflow",
        status: "running",
        started_at: new Date(Date.now() - 2000).toISOString(),
        finished_at: null,
        steps: [],
      };
      pretender.get("/admin/plugins/discourse-workflows/executions/11475", () =>
        response(200, {
          execution: {
            ...this.execution,
            status: "success",
            run_time_ms: 2500,
            finished_at: new Date().toISOString(),
            steps: [
              {
                node_id: "node-1",
                node_name: "Authoritative step",
                node_type: "action:code",
                position: 0,
                status: "success",
                input: [],
                output: [{ json: { result: "complete" } }],
                started_at: this.execution.started_at,
                finished_at: new Date().toISOString(),
              },
            ],
          },
        })
      );

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );
      await publishToMessageBus("/discourse-workflows/execution/11475", {
        type: "execution_progress",
        execution: { id: 11475, status: "success", run_time_ms: 2500 },
        refresh: true,
      });

      assert
        .dom(".workflows-execution-detail__step-name")
        .hasText(
          "Authoritative step",
          "the persisted execution replaces the compact live summary"
        );
      assert
        .dom(".workflows-execution-detail__progress")
        .doesNotExist("the running indicator is removed");
    });

    test("shows live progress for a running execution", async function (assert) {
      this.execution = {
        id: 11473,
        workflow_id: 30,
        workflow_name: "Running workflow",
        status: "running",
        started_at: new Date(Date.now() - 2000).toISOString(),
        finished_at: null,
        steps: [],
      };

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );

      assert
        .dom(".workflows-execution-detail__progress-label")
        .hasText("Running", "the running status is visible");
      assert
        .dom(".workflows-execution-detail__progress .spinner")
        .exists("a spinner communicates ongoing work");
      assert
        .dom(".workflows-execution-detail__progress-time")
        .hasText("2.0s", "the elapsed time advances in whole seconds");

      await publishToMessageBus("/discourse-workflows/execution/11473", {
        type: "execution_progress",
        execution: { id: 11473, status: "running" },
        refresh: false,
        step: {
          node_id: "node-1",
          node_name: "Fetch topic",
          node_type: "action:code",
          position: 0,
          status: "running",
          started_at: new Date().toISOString(),
          finished_at: null,
        },
      });

      assert
        .dom(".workflows-execution-detail__step")
        .exists({ count: 1 }, "the server event adds the running step");
      assert
        .dom(".workflows-execution-detail__step-name")
        .hasText("Fetch topic", "the live step name is visible");
      assert
        .dom(".workflows-execution-detail__step-badge")
        .hasText("Running", "the live step status is visible");
    });
  }
);
