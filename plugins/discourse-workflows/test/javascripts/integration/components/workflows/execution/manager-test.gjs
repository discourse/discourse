import Service from "@ember/service";
import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ExecutionsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/execution/manager";

class MessageBusStub extends Service {
  subscriptions = new Map();

  subscribe(channel, handler, lastId) {
    this.subscriptions.set(channel, { handler, lastId });
  }

  unsubscribe(channel) {
    this.subscriptions.delete(channel);
  }

  publish(channel, message) {
    this.subscriptions.get(channel)?.handler(message);
  }
}

module(
  "Integration | Component | Workflows | Execution | ExecutionsManager",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.owner.unregister("service:message-bus");
      this.owner.register("service:message-bus", MessageBusStub);
      this.startedAt = new Date(Date.now() - 2000).toISOString();
      this.executionStatus = "running";

      pretender.get(
        "/admin/plugins/discourse-workflows/workflows/30/executions.json",
        () =>
          response(200, {
            executions: [
              {
                id: 11473,
                workflow_id: 30,
                workflow_name: "Running workflow",
                status: this.executionStatus,
                run_time_ms: null,
                started_at: this.startedAt,
                finished_at: null,
              },
            ],
            meta: {},
          })
      );
    });

    test("shows and updates live execution progress", async function (assert) {
      await render(
        <template><ExecutionsManager @workflowId={{30}} /></template>
      );
      await waitFor(".workflows-executions-manager__status");

      const messageBus = this.owner.lookup("service:message-bus");
      const subscription = messageBus.subscriptions.get(
        "/discourse-workflows/execution/11473"
      );

      assert.strictEqual(
        subscription.lastId,
        0,
        "progress emitted before the list loaded is replayed"
      );
      assert
        .dom(".workflows-executions-manager__status .spinner")
        .exists("running rows use an animated spinner");
      assert
        .dom(".workflows-executions-manager__run-time")
        .containsText("2.0s", "running rows show whole-second elapsed time");

      messageBus.publish("/discourse-workflows/execution/11473", {
        type: "execution_progress",
        execution: {
          id: 11473,
          status: "success",
          run_time_ms: 3456,
          finished_at: new Date().toISOString(),
        },
        refresh: true,
      });
      await settled();

      assert
        .dom(".workflows-executions-manager__status")
        .hasText("Completed", "the terminal status updates without reloading");
      assert
        .dom(".workflows-executions-manager__status .d-icon-circle-check")
        .exists("the terminal status icon replaces the spinner");
      assert
        .dom(".workflows-executions-manager__run-time")
        .containsText("3.5s", "the final run time comes from the server event");
      assert.false(
        messageBus.subscriptions.has("/discourse-workflows/execution/11473"),
        "the completed execution is unsubscribed"
      );
    });
    test("keeps waiting executions live through resume and completion", async function (assert) {
      this.executionStatus = "waiting";
      await render(
        <template><ExecutionsManager @workflowId={{30}} /></template>
      );
      await waitFor(".workflows-executions-manager__status");

      const messageBus = this.owner.lookup("service:message-bus");
      const channel = "/discourse-workflows/execution/11473";
      assert.true(
        messageBus.subscriptions.has(channel),
        "the waiting execution remains subscribed"
      );
      assert
        .dom(".workflows-executions-manager__status")
        .hasText("Waiting", "the waiting status is shown");
      assert
        .dom(".workflows-executions-manager__status .spinner")
        .doesNotExist("waiting does not look like active processing");

      messageBus.publish(channel, {
        type: "execution_progress",
        execution: {
          id: 11473,
          status: "running",
          started_at: this.startedAt,
        },
        refresh: false,
      });
      await settled();

      assert
        .dom(".workflows-executions-manager__status .spinner")
        .exists("the spinner returns when execution resumes");

      messageBus.publish(channel, {
        type: "execution_progress",
        execution: {
          id: 11473,
          status: "success",
          run_time_ms: 4200,
          finished_at: new Date().toISOString(),
        },
        refresh: true,
      });
      await settled();

      assert
        .dom(".workflows-executions-manager__status")
        .hasText("Completed", "the resumed execution completes live");
      assert.false(
        messageBus.subscriptions.has(channel),
        "the terminal execution is unsubscribed"
      );
    });
  }
);
