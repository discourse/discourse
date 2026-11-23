import {
  click,
  find,
  settled,
  visit,
  waitFor,
  waitUntil,
} from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import pretender from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  loggedInUser,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const postButton = "#post_1 .post-controls .workflow-post-button-1";

acceptance("Discourse Workflows | Post button", function (needs) {
  needs.user();
  needs.site({
    post_button_workflows: [
      {
        trigger_node_id: "trigger-1",
        workflow_id: 1,
        label: "Run workflow",
        icon: "bolt",
        position: "first",
        confirmation: false,
        confirmation_message: null,
      },
      {
        trigger_node_id: "trigger-1",
        workflow_id: 2,
        label: "Escalate",
        icon: null,
        position: "more_menu",
        confirmation: false,
        confirmation_message: null,
      },
      {
        trigger_node_id: "trigger-1",
        workflow_id: 3,
        label: "Danger",
        icon: "triangle-exclamation",
        position: "last",
        confirmation: true,
        confirmation_message: "Really run this?",
      },
      {
        trigger_node_id: "trigger-1",
        workflow_id: 4,
        label: "Next to like",
        icon: null,
        position: "after_like",
        confirmation: false,
        confirmation_message: null,
      },
      {
        trigger_node_id: "trigger-1",
        workflow_id: 5,
        label: "Custom anchor",
        icon: null,
        position: "after_some-plugin-button",
        confirmation: false,
        confirmation_message: null,
      },
      {
        trigger_node_id: "trigger-1",
        workflow_id: 6,
        label: "Only post two",
        icon: null,
        post_number: 2,
        position: "last",
        confirmation: false,
        confirmation_message: null,
      },
      {
        trigger_node_id: "trigger-1",
        workflow_id: 7,
        label: "Any post",
        icon: null,
        post_number: null,
        position: "last",
        confirmation: false,
        confirmation_message: null,
      },
    ],
  });

  let lastRequestBody = null;

  needs.pretender((server, helper) => {
    server.post("/discourse-workflows/trigger-post-button", (request) => {
      lastRequestBody = request.requestBody;
      return helper.response({});
    });
  });

  needs.hooks.beforeEach(() => (lastRequestBody = null));

  function feedbackChannel() {
    return `/discourse-workflows/post-button/${loggedInUser().id}/${new URLSearchParams(lastRequestBody).get("request_id")}`;
  }

  test("renders the button at the configured position and triggers the workflow", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const toasts = this.owner.lookup("service:toasts");
    const startingToast = sinon.spy(toasts.info);
    sinon.replaceGetter(toasts, "info", () => startingToast);

    assert
      .dom("#post_1 .post-controls .actions > :first-child")
      .hasClass(
        "workflow-post-button-1",
        "the first-position button renders first in the actions row"
      );

    await click(postButton);

    const params = new URLSearchParams(lastRequestBody);
    assert.strictEqual(
      params.get("workflow_id"),
      "1",
      "submits the workflow id"
    );
    assert.strictEqual(
      params.get("trigger_node_id"),
      "trigger-1",
      "submits the trigger node id"
    );
    assert.true(
      Number(params.get("post_id")) > 0,
      "submits the clicked post's id"
    );
    assert.strictEqual(
      params.get("client_id"),
      this.owner.lookup("service:message-bus").clientId,
      "submits the MessageBus client ID of this tab"
    );
    assert.strictEqual(
      startingToast.firstCall?.args[0].data.message,
      i18n("discourse_workflows.post_button.starting"),
      "acknowledges the click"
    );
  });

  test("starts the workflow without feedback when randomUUID is unavailable", async function (assert) {
    await visit("/t/internationalization-localization/280");
    sinon.stub(crypto, "randomUUID").value(undefined);

    await click(postButton);

    const params = new URLSearchParams(lastRequestBody);
    assert.strictEqual(
      params.get("workflow_id"),
      "1",
      "the workflow is still triggered"
    );
    assert.false(params.has("request_id"), "no feedback channel is requested");
  });

  test("prevents repeated clicks while submitting and then re-enables the button", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const requests = [];
    const path = "/discourse-workflows/trigger-post-button";
    pretender.post(
      path,
      (request) => {
        requests.push(request);
        return [204, {}, ""];
      },
      true
    );

    find(postButton).click();
    find(postButton).click();

    try {
      await waitFor(`${postButton}[disabled]`);
      await waitUntil(() => requests.length > 0);
      assert
        .dom(postButton)
        .hasClass("is-loading", "shows the pending request");
      assert.strictEqual(
        requests.length,
        1,
        "the second click does not submit"
      );
    } finally {
      requests.forEach((request) => pretender.resolve(request));
    }

    await settled();
    assert
      .dom(postButton)
      .isNotDisabled("can run again after the request finishes");
  });

  test("keeps each run subscribed until its own terminal event", async function (assert) {
    await visit("/t/internationalization-localization/280");
    const messageBus = this.owner.lookup("service:message-bus");
    const unsubscribe = sinon.spy(messageBus, "unsubscribe");
    await click(postButton);
    const first = feedbackChannel();
    await click(postButton);
    const second = feedbackChannel();
    assert.notStrictEqual(first, second, "each click has a separate channel");

    await publishToMessageBus(first, { status: "waiting" });
    assert.false(
      unsubscribe.calledWith(first),
      "an approval pause is not terminal"
    );
    await publishToMessageBus(first, { status: "success" });
    assert.true(
      unsubscribe.calledWith(first),
      "success unsubscribes the first run"
    );
    assert.false(
      unsubscribe.calledWith(second),
      "the other run is still listening"
    );
    await publishToMessageBus(second, { status: "skipped" });
    assert.true(
      unsubscribe.calledWith(second),
      "a skipped run also unsubscribes"
    );
  });

  test("cleans up feedback if the request fails", async function (assert) {
    await visit("/t/internationalization-localization/280");
    const messageBus = this.owner.lookup("service:message-bus");
    const unsubscribe = sinon.spy(messageBus, "unsubscribe");
    pretender.post("/discourse-workflows/trigger-post-button", (request) => {
      lastRequestBody = request.requestBody;
      return [
        422,
        { "Content-Type": "application/json" },
        '{"errors":["Could not start the workflow"]}',
      ];
    });

    await click(postButton);

    assert.true(
      unsubscribe.calledWith(feedbackChannel()),
      "a failed POST removes its listener"
    );
    assert.dom(postButton).isNotDisabled("the button is available to retry");
  });

  test("cleans up feedback if no terminal event arrives before the timeout", async function (assert) {
    await visit("/t/internationalization-localization/280");
    const messageBus = this.owner.lookup("service:message-bus");
    const unsubscribe = sinon.spy(messageBus, "unsubscribe");
    const timeout = sinon
      .stub(window, "setTimeout")
      .callThrough()
      .withArgs(sinon.match.func, 60 * 60 * 1000)
      .returns(-1);

    await click(postButton);
    assert.false(
      unsubscribe.calledWith(feedbackChannel()),
      "the run is still listening"
    );
    timeout.firstCall.args[0]();

    assert.true(
      unsubscribe.calledWith(feedbackChannel()),
      "the timeout removes its listener"
    );
  });

  for (const status of ["rate_limited", "error"]) {
    test(`shows an asynchronous ${status} toast`, async function (assert) {
      await visit("/t/internationalization-localization/280");
      const toasts = this.owner.lookup("service:toasts");
      const errorToast = sinon.spy(toasts.error);
      sinon.replaceGetter(toasts, "error", () => errorToast);
      await click(postButton);
      await publishToMessageBus(feedbackChannel(), { status });

      assert.strictEqual(
        errorToast.firstCall?.args[0].data.message,
        i18n(`discourse_workflows.post_button.${status}`),
        "shows the localized failure feedback"
      );
    });
  }

  test("relative positions render immediately next to their anchor", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const children = [
      ...document.querySelectorAll("#post_1 .post-controls .actions > *"),
    ];
    const likeIndex = children.findIndex(
      (child) =>
        child.matches(".post-action-menu__like") ||
        child.querySelector(".post-action-menu__like")
    );
    const buttonIndex = children.findIndex((child) =>
      child.classList.contains("workflow-post-button-4")
    );

    assert.true(likeIndex >= 0, "the like button renders");
    assert.strictEqual(
      buttonIndex,
      likeIndex + 1,
      "the after-like button renders immediately after the like button"
    );
  });

  test("custom anchors pointing at unknown buttons still render", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 .post-controls .workflow-post-button-5")
      .exists("the button falls back gracefully when its anchor is absent");
  });

  test("filters workflow buttons by post number", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 .post-controls .workflow-post-button-6")
      .doesNotExist("the restricted workflow is absent from post one");
    assert
      .dom("#post_2 .post-controls .workflow-post-button-6")
      .exists("the restricted workflow renders on post two");

    assert
      .dom("#post_1 .post-controls .workflow-post-button-1")
      .exists("a workflow without a post number renders on post one");
    assert
      .dom("#post_2 .post-controls .workflow-post-button-1")
      .exists("a workflow without a post number renders on post two");
    assert
      .dom("#post_1 .post-controls .workflow-post-button-7")
      .exists("a workflow with a null post number renders on post one");
    assert
      .dom("#post_2 .post-controls .workflow-post-button-7")
      .exists("a workflow with a null post number renders on post two");
  });

  test("show-more buttons render in the show-more menu", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 .post-controls .workflow-post-button-2")
      .doesNotExist("the show-more button is not in the actions row");

    await click("#post_1 .post-controls .show-more-actions");

    assert
      .dom("#post_1 .post-controls .workflow-post-button-2")
      .exists("the show-more button appears after expanding");
  });

  test("confirmation buttons only trigger after the dialog is confirmed", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#post_1 .post-controls .workflow-post-button-3");

    assert
      .dom(".dialog-body")
      .hasText("Really run this?", "shows the configured message");
    assert.strictEqual(lastRequestBody, null, "does not trigger before answer");

    await click(".dialog-footer .btn-default");

    assert.strictEqual(
      lastRequestBody,
      null,
      "does not trigger when cancelled"
    );

    await click("#post_1 .post-controls .workflow-post-button-3");
    await click(".dialog-footer .btn-primary");

    const params = new URLSearchParams(lastRequestBody);
    assert.strictEqual(
      params.get("trigger_node_id"),
      "trigger-1",
      "triggers the workflow after confirming"
    );
  });
});

acceptance(
  "Discourse Workflows | Post button (feature unused)",
  function (needs) {
    needs.user();

    test("does not render workflow buttons when none are published", async function (assert) {
      await visit("/t/internationalization-localization/280");

      assert
        .dom("#post_1 .post-controls [class*='workflow-post-button']")
        .doesNotExist("no workflow button renders");
    });
  }
);
