import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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

  test("renders the button at the configured position and triggers the workflow", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 .post-controls .actions > :first-child")
      .hasClass(
        "workflow-post-button-1",
        "the first-position button renders first in the actions row"
      );

    await click("#post_1 .post-controls .workflow-post-button-1");

    const params = new URLSearchParams(lastRequestBody);
    assert.strictEqual(
      params.get("trigger_node_id"),
      "trigger-1",
      "submits the trigger node id"
    );
    assert.true(
      Number(params.get("post_id")) > 0,
      "submits the clicked post's id"
    );
  });

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
