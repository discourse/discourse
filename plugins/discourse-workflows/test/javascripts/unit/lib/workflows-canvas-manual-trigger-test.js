import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { runManualTrigger } from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-manual-trigger";

module("Unit | Utility | workflows canvas manual trigger", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    sinon.restore();
  });

  test("starts a form test session instead of opening the production form URL", async function (assert) {
    sinon.stub(window, "open");
    pretender.post(
      "/admin/plugins/discourse-workflows/workflows/7/form-test-sessions.json",
      (request) => {
        assert.strictEqual(request.requestBody, "trigger_node_id=trigger-1");
        return response(201, {
          test_url: "/workflows/form-test/test-token",
        });
      }
    );

    await runManualTrigger({
      node: {
        type: "trigger:form",
        webhookId: "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
      },
      clientId: "trigger-1",
      workflowId: 7,
    });

    assert.true(window.open.calledOnce);
    assert.true(
      window.open.calledWith(
        "http://localhost:3000/workflows/form-test/test-token",
        "_blank"
      )
    );
  });

  test("starts a webhook test listener instead of opening the production webhook URL", async function (assert) {
    sinon.stub(window, "open");
    const toasts = { success: sinon.stub() };
    const session = {
      startWebhookTestListener: sinon.stub().resolves({
        listenerId: "listener-1",
        testUrl: "/workflows/webhook-test/listener-1/test-hook",
        expiresAt: "2026-05-22T12:00:00Z",
      }),
    };

    await runManualTrigger({
      node: {
        type: "trigger:webhook",
        configuration: {
          path: "test-hook",
        },
      },
      clientId: "webhook-1",
      workflowId: 7,
      toasts,
      session,
    });

    assert.true(window.open.notCalled);
    assert.true(session.startWebhookTestListener.calledWith("webhook-1"));
    assert.true(toasts.success.calledOnce);
  });
});
