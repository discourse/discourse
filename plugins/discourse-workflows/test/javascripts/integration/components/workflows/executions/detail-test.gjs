import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
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

function executionWithOutput(output) {
  return {
    id: 11473,
    workflow_id: 30,
    workflow_name: "Output workflow",
    status: "success",
    started_at: "2026-06-24T10:00:00Z",
    finished_at: "2026-06-24T10:00:01Z",
    steps: [
      {
        node_id: "code-1",
        node_name: "Code",
        node_type: "action:code",
        status: "success",
        input: [{ json: { value: 1 } }],
        output,
        metadata: {},
        started_at: "2026-06-24T10:00:00Z",
        finished_at: "2026-06-24T10:00:01Z",
      },
    ],
  };
}

class MessageBusStub extends Service {
  subscriptions = new Map();

  subscribe(channel, handler, lastId) {
    this.subscriptions.set(channel, { handler, lastId });
  }

  unsubscribe(channel) {
    this.subscriptions.delete(channel);
  }

  publish(channel, message, messageId) {
    this.subscriptions.get(channel)?.handler(message, null, messageId);
  }
}

class ReplayMessageBusStub extends Service {
  subscribe(channel, handler, lastId) {
    if (lastId === 40) {
      handler(
        {
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
        },
        null,
        41
      );
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
      this.owner.unregister("service:message-bus");
      this.owner.register("service:message-bus", MessageBusStub);
      this.clock = fakeTime("2026-08-13T05:00:02Z", "UTC", true);
    });

    hooks.afterEach(function () {
      this.clock.restore();
    });

    test("explains when a successful node returns no output", async function (assert) {
      this.execution = executionWithOutput([]);

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );

      assert
        .dom(".workflows-execution-detail__no-output")
        .hasText(
          "This node produced no output data, so the execution stopped and no items were passed to connected nodes. To continue the execution with an empty item, turn on Always output data in this node's Settings tab.",
          "the execution explains empty-output routing and how to emit an item"
        );
      assert
        .dom(".workflows-execution-detail__step-section:last-of-type pre")
        .hasText("[]", "zero output items are displayed as an empty array");
    });

    test("does not show the explanation for an empty output item", async function (assert) {
      this.execution = executionWithOutput([{ json: {} }]);

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );

      assert
        .dom(".workflows-execution-detail__no-output")
        .doesNotExist(
          "an empty item can continue to following nodes and needs no warning"
        );
      assert
        .dom(".workflows-execution-detail__step-section:last-of-type pre")
        .hasText("{}", "the empty item remains distinguishable from no items");
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
        message_bus_last_id: 40,
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
        message_bus_last_id: 40,
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
          meta: { message_bus_last_id: 41 },
        })
      );

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );
      this.owner.lookup("service:message-bus").publish(
        "/discourse-workflows/execution/11475",
        {
          type: "execution_progress",
          execution: { id: 11475, status: "success", run_time_ms: 2500 },
          refresh: true,
        },
        41
      );
      await settled();

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

    test("replaces partial progress when a message gap is detected", async function (assert) {
      this.execution = {
        id: 11476,
        workflow_id: 30,
        workflow_name: "Running workflow",
        status: "running",
        message_bus_last_id: 40,
        started_at: new Date(Date.now() - 2000).toISOString(),
        finished_at: null,
        steps: [],
      };
      pretender.get("/admin/plugins/discourse-workflows/executions/11476", () =>
        response(200, {
          execution: {
            ...this.execution,
            steps: [
              {
                node_id: "node-authoritative",
                node_name: "Recovered step",
                node_type: "action:code",
                position: 0,
                status: "success",
                input: [],
                output: [],
                started_at: "2026-08-13T05:00:00Z",
                finished_at: "2026-08-13T05:00:01Z",
              },
            ],
          },
          meta: { message_bus_last_id: 45 },
        })
      );

      await render(
        <template><ExecutionDetail @execution={{this.execution}} /></template>
      );
      this.owner.lookup("service:message-bus").publish(
        "/discourse-workflows/execution/11476",
        {
          type: "execution_progress",
          execution: { id: 11476, status: "running" },
          step: {
            node_id: "node-partial",
            node_name: "Skipped partial step",
            node_type: "action:code",
            position: 1,
            status: "running",
          },
        },
        44
      );
      await settled();

      assert
        .dom(".workflows-execution-detail__step-name")
        .hasText(
          "Recovered step",
          "the authoritative response repairs the gap"
        );
      assert
        .dom(".workflows-execution-detail__step")
        .exists({ count: 1 }, "the out-of-sequence event is not merged");
      assert.strictEqual(
        this.owner
          .lookup("service:message-bus")
          .subscriptions.get("/discourse-workflows/execution/11476").lastId,
        45,
        "the recovered stream resumes at the response cursor"
      );
    });

    test("shows live progress for a running execution", async function (assert) {
      this.execution = {
        id: 11473,
        workflow_id: 30,
        workflow_name: "Running workflow",
        status: "running",
        message_bus_last_id: 40,
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
        .hasText("2s", "the elapsed time advances in whole seconds");

      this.owner.lookup("service:message-bus").publish(
        "/discourse-workflows/execution/11473",
        {
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
        },
        41
      );
      await settled();

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
