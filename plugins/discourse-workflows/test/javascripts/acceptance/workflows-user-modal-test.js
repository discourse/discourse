import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  loggedInUser,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Discourse Workflows | User modal", function (needs) {
  // Present only when a published workflow uses a modal node; gates the
  // subscription and provides the channel's starting message-bus id.
  needs.user({ discourse_workflows_user_modal_last_id: 0 });

  let lastRequestBody = null;

  needs.pretender((server, helper) => {
    server.post("/discourse-workflows/modal-responses", (request) => {
      lastRequestBody = request.requestBody;
      return helper.response({});
    });
  });

  needs.hooks.beforeEach(() => (lastRequestBody = null));

  function channel() {
    return `/discourse-workflows/user-modal/${loggedInUser().id}`;
  }

  const payload = {
    type: "show_modal",
    title: "Approve topic?",
    body: "Please choose an option",
    buttons: [
      {
        label: "Approve",
        value: "approve",
        style: "primary",
        action_id: "1:approve:sig-approve",
      },
      {
        label: "Reject",
        value: "reject",
        style: "danger",
        action_id: "1:reject:sig-reject",
      },
    ],
  };

  test("opens a modal with the configured title, body, and buttons", async function (assert) {
    await visit("/");
    await publishToMessageBus(channel(), payload);
    await settled();

    assert.dom(".workflows-user-modal").exists("the modal opens");
    assert.dom(".d-modal__title-text").hasText("Approve topic?");
    assert
      .dom(".workflows-user-modal__body")
      .hasText("Please choose an option");
    assert
      .dom(".d-modal__footer .btn")
      .exists({ count: 2 }, "renders one button per configured option");
    assert.dom(".d-modal__footer .btn-primary").hasText("Approve");
    assert.dom(".d-modal__footer .btn-danger").hasText("Reject");
  });

  test("posts the chosen button's action id and closes the modal", async function (assert) {
    await visit("/");
    await publishToMessageBus(channel(), payload);
    await settled();

    await click(".d-modal__footer .btn-primary");

    assert.strictEqual(
      new URLSearchParams(lastRequestBody).get("action_id"),
      "1:approve:sig-approve",
      "submits the action id of the clicked button"
    );
    assert.dom(".workflows-user-modal").doesNotExist("the modal closes");
  });

  test("ignores message bus payloads of other types", async function (assert) {
    await visit("/");
    await publishToMessageBus(channel(), { type: "something_else" });
    await settled();

    assert.dom(".workflows-user-modal").doesNotExist("no modal is opened");
  });
});

acceptance(
  "Discourse Workflows | User modal (feature unused)",
  function (needs) {
    // No `discourse_workflows_user_modal_last_id` on the user: no published
    // workflow uses a modal node, so the initializer must not subscribe.
    needs.user();

    test("does not subscribe when no workflow uses a modal node", async function (assert) {
      await visit("/");
      await publishToMessageBus(
        `/discourse-workflows/user-modal/${loggedInUser().id}`,
        {
          type: "show_modal",
          title: "Should not appear",
          buttons: [],
        }
      );
      await settled();

      assert.dom(".workflows-user-modal").doesNotExist("no modal is opened");
    });
  }
);
