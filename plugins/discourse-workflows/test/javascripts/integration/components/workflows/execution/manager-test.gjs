import Service from "@ember/service";
import { render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import ExecutionsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/execution/manager";

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

module(
  "Integration | Component | Workflows | Execution | ExecutionsManager",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.owner.unregister("service:message-bus");
      this.owner.register("service:message-bus", MessageBusStub);
      this.clock = fakeTime("2026-08-13T05:00:02Z", "UTC", true);
      this.executionStatus = "running";
      this.requestCount = 0;
      this.messageBusLastId = 40;

      pretender.get(
        "/admin/plugins/discourse-workflows/workflows/30/executions.json",
        () => {
          this.requestCount++;
          return response(200, {
            executions: [
              {
                id: 11473,
                workflow_id: 30,
                workflow_name: "Running workflow",
                status: this.executionStatus,
                run_time_ms: null,
                started_at: "2026-08-13T05:00:00Z",
                finished_at: null,
              },
            ],
            meta: { message_bus_last_id: this.messageBusLastId },
          });
        }
      );
    });

    hooks.afterEach(function () {
      this.clock.restore();
    });

    test("uses one aggregate subscription for lifecycle updates", async function (assert) {
      await render(
        <template><ExecutionsManager @workflowId={{30}} /></template>
      );
      await waitFor(".workflows-executions-manager__status");

      const messageBus = this.owner.lookup("service:message-bus");
      const channel = "/discourse-workflows/executions";
      assert.strictEqual(
        messageBus.subscriptions.get(channel).lastId,
        40,
        "the subscription continues from the list response cursor"
      );
      assert.strictEqual(
        messageBus.subscriptions.size,
        1,
        "the list has one subscription regardless of live execution count"
      );
      assert
        .dom(".workflows-executions-manager__status .spinner")
        .exists("running rows use an animated spinner");
      assert
        .dom(".workflows-executions-manager__run-time")
        .containsText("2.0s", "running rows show deterministic elapsed time");

      messageBus.publish(
        channel,
        {
          type: "execution_update",
          execution: {
            id: 11473,
            workflow_id: 30,
            status: "success",
            run_time_ms: 3456,
            finished_at: "2026-08-13T05:00:02Z",
          },
        },
        41
      );
      await settled();

      assert
        .dom(".workflows-executions-manager__status")
        .hasText("Completed", "the terminal status updates without reloading");
      assert
        .dom(".workflows-executions-manager__run-time")
        .containsText(
          "3.5s",
          "the final processing time comes from the server"
        );
      assert.true(
        messageBus.subscriptions.has(channel),
        "the aggregate subscription remains for future executions"
      );
    });

    test("inserts newly created executions in id order and ignores unloaded updates", async function (assert) {
      await render(
        <template><ExecutionsManager @workflowId={{30}} /></template>
      );
      await waitFor(".workflows-executions-manager__status");

      const messageBus = this.owner.lookup("service:message-bus");
      const channel = "/discourse-workflows/executions";
      messageBus.publish(
        channel,
        {
          type: "execution_update",
          execution: { id: 100, workflow_id: 30, status: "waiting" },
        },
        41
      );
      messageBus.publish(
        channel,
        {
          type: "execution_created",
          execution: {
            id: 12000,
            workflow_id: 30,
            workflow_name: "New workflow",
            status: "pending",
          },
        },
        42
      );
      await settled();

      assert
        .dom(".workflows-executions-manager__status")
        .exists(
          { count: 2 },
          "only created executions are added to the loaded page"
        );
      assert
        .dom(".d-table__row:first-child .workflows-executions-manager__status")
        .hasText("Pending", "the newer execution is placed first");
    });

    test("distinguishes queued executions from active processing", async function (assert) {
      this.executionStatus = "pending";

      await render(
        <template><ExecutionsManager @workflowId={{30}} /></template>
      );
      await waitFor(".workflows-executions-manager__status");

      assert
        .dom(".workflows-executions-manager__status")
        .hasText("Pending", "the queued state is shown");
      assert
        .dom(".workflows-executions-manager__status .spinner")
        .doesNotExist("queued work does not look like active processing");
      assert
        .dom(".workflows-executions-manager__run-time")
        .containsText("—", "queued work has no elapsed processing time");
    });

    test("reloads authoritative data when aggregate messages have a gap", async function (assert) {
      await render(
        <template><ExecutionsManager @workflowId={{30}} /></template>
      );
      await waitFor(".workflows-executions-manager__status");

      this.executionStatus = "success";
      this.messageBusLastId = 45;
      this.owner.lookup("service:message-bus").publish(
        "/discourse-workflows/executions",
        {
          type: "execution_update",
          execution: { id: 11473, workflow_id: 30, status: "running" },
        },
        44
      );
      await settled();

      assert.strictEqual(this.requestCount, 2, "the list is fetched again");
      assert
        .dom(".workflows-executions-manager__status")
        .hasText("Completed", "the response replaces the skipped event state");
      assert.strictEqual(
        this.owner
          .lookup("service:message-bus")
          .subscriptions.get("/discourse-workflows/executions").lastId,
        45,
        "the replacement subscription uses the refreshed cursor"
      );
    });
  }
);
