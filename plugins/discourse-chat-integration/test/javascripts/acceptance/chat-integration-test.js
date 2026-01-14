import { click, fillIn, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const response = (object) => {
  return [200, { "Content-Type": "text/html; charset=utf-8" }, object];
};

const jsonResponse = (object) => {
  return [200, { "Content-Type": "application/json; charset=utf-8" }, object];
};

acceptance("Chat Integration", function (needs) {
  needs.user();

  needs.pretender((server) => {
    server.get("/admin/plugins/chat-integration/providers", () => {
      return jsonResponse({
        providers: [
          {
            name: "dummy",
            id: "dummy",
            channel_parameters: [{ key: "somekey", regex: "^\\S+$" }],
          },
        ],
      });
    });

    server.get("/admin/plugins/chat-integration/channels", () => {
      return jsonResponse({
        channels: [
          {
            id: 97,
            provider: "dummy",
            data: { somekey: "#general" },
            rules: [
              {
                id: 98,
                channel_id: 97,
                category_id: null,
                team_id: null,
                type: "normal",
                tags: [],
                filter: "watch",
                error_key: null,
              },
            ],
          },
        ],
      });
    });

    server.post("/admin/plugins/chat-integration/channels", () => {
      return response({});
    });

    server.put("/admin/plugins/chat-integration/channels/:id", () => {
      return response({});
    });

    server.delete("/admin/plugins/chat-integration/channels/:id", () => {
      return response({});
    });

    server.post("/admin/plugins/chat-integration/rules", () => {
      return response({});
    });

    server.put("/admin/plugins/chat-integration/rules/:id", () => {
      return response({});
    });

    server.delete("/admin/plugins/chat-integration/rules/:id", () => {
      return response({});
    });

    server.post("/admin/plugins/chat-integration/test", () => {
      return response({});
    });

    server.get("/groups/search.json", () => {
      return jsonResponse([]);
    });
  });

  test("Rules load successfully", async function (assert) {
    await visit("/admin/plugins/chat-integration");

    assert
      .dom("#admin-plugin-chat table")
      .exists("it shows the table of rules");

    assert
      .dom("#admin-plugin-chat table tr td")
      .hasText("All posts and replies", "rule displayed");
  });

  test("Create channel works", async function (assert) {
    await visit("/admin/plugins/chat-integration");
    await click("#create-channel");

    assert
      .dom("#chat-integration-edit-channel-modal")
      .exists("it displays the modal");
    assert.dom("#save-channel").isDisabled();

    await fillIn("#chat-integration-edit-channel-modal input", "#general");

    assert.dom("#save-channel").isEnabled();

    await click("#save-channel");

    assert
      .dom("#chat-integration-edit-channel-modal")
      .doesNotExist("modal closes on save");
  });

  test("Edit channel works", async function (assert) {
    await visit("/admin/plugins/chat-integration");
    await click(".channel-header button");

    assert
      .dom("#chat-integration-edit-channel-modal")
      .exists("it displays the modal");
    assert.dom("#save-channel").isEnabled();

    await fillIn("#chat-integration-edit-channel-modal input", " general");
    assert.dom("#save-channel").isDisabled();

    await fillIn("#chat-integration-edit-channel-modal input", "#random");
    assert.dom("#save-channel").isEnabled();

    // Press enter
    await triggerEvent("#chat-integration-edit-channel-modal", "submit");

    assert
      .dom("#chat-integration-edit-channel-modal")
      .doesNotExist("modal saves on enter");
  });

  test("Create rule works", async function (assert) {
    await visit("/admin/plugins/chat-integration");

    assert.dom(".channel-footer button").exists("create button is displayed");

    await click(".channel-footer button");

    assert
      .dom("#chat-integration-edit-rule_modal")
      .exists("modal opens on edit");
    assert.dom("#save-rule").isEnabled();

    await click("#save-rule");

    assert
      .dom("#chat-integration-edit-rule_modal")
      .doesNotExist("modal closes on save");
  });

  test("Edit rule works", async function (assert) {
    await visit("/admin/plugins/chat-integration");

    assert.dom(".edit").exists("edit button is displayed");

    await click(".edit");

    assert
      .dom("#chat-integration-edit-rule_modal")
      .exists("modal opens on edit");
    assert.dom("#save-rule").isEnabled();

    await click("#save-rule");

    assert
      .dom("#chat-integration-edit-rule_modal")
      .doesNotExist("modal closes on save");
  });

  test("Delete channel works", async function (assert) {
    await visit("/admin/plugins/chat-integration");

    assert
      .dom(".channel-header .delete-channel")
      .exists("delete buttons exists");
    await click(".channel-header .delete-channel");

    assert.dom("div.dialog-content").exists("dialog is displayed");
    await click("div.dialog-content .btn-danger");

    assert.dom("div.dialog-content").doesNotExist("dialog has closed");
  });

  test("Delete rule works", async function (assert) {
    await visit("/admin/plugins/chat-integration");

    assert.dom(".delete").exists();
    await click(".delete");
  });

  test("Test channel works", async function (assert) {
    await visit("/admin/plugins/chat-integration");

    await click(".btn-chat-test");

    assert.dom("#chat_integration_test_modal").exists("it displays the modal");
    assert.dom("#send-test").isDisabled();

    await fillIn("#choose-topic-title", "9318");
    await click("#chat_integration_test_modal .radio");

    assert.dom("#send-test").isEnabled();

    await click("#send-test");

    assert
      .dom("#chat_integration_test_modal")
      .exists("modal doesn't close on send");
    assert
      .dom("#modal-alert.alert-success")
      .exists("success message displayed");
  });
});
