import { click, fillIn, visit } from "@ember/test-helpers";
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
    server.get("/admin/plugins/discourse-chat-integration.json", () => {
      return jsonResponse({
        id: "discourse-chat-integration",
        name: "discourse-chat-integration",
        about: "Test plugin",
        version: "1.0.0",
        enabled: true,
      });
    });

    server.get("/admin/plugins/discourse-chat-integration/providers", () => {
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

    server.get("/admin/plugins/discourse-chat-integration/channels", () => {
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

    server.post("/admin/plugins/discourse-chat-integration/channels", () => {
      return response({});
    });

    server.put("/admin/plugins/discourse-chat-integration/channels/:id", () => {
      return response({});
    });

    server.delete(
      "/admin/plugins/discourse-chat-integration/channels/:id",
      () => {
        return response({});
      }
    );

    server.post("/admin/plugins/discourse-chat-integration/rules", () => {
      return response({});
    });

    server.put("/admin/plugins/discourse-chat-integration/rules/:id", () => {
      return response({});
    });

    server.delete("/admin/plugins/discourse-chat-integration/rules/:id", () => {
      return response({});
    });

    server.post("/admin/plugins/discourse-chat-integration/test", () => {
      return response({});
    });

    server.get("/groups/search.json", () => {
      return jsonResponse([]);
    });
  });

  test("Rules load successfully", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");

    assert
      .dom("#admin-plugin-chat .d-admin-table")
      .exists("it shows the table of rules");

    assert
      .dom("#admin-plugin-chat .d-admin-table .d-admin-row__detail.rule-filter")
      .hasText(/All posts and replies/, "rule displayed");
  });

  test("Create channel works", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");
    await click("#create-channel");

    assert.dom(".inline-channel-form").exists("it displays the inline form");

    await fillIn(".inline-channel-form input", "#general");

    await click(".inline-channel-form .btn-primary");

    assert.dom(".inline-channel-form").doesNotExist("form closes on save");
  });

  test("Edit channel works", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");

    // Open the channel actions dropdown menu
    await click(".channel-header .fk-d-menu__trigger");
    await click(".edit-channel");

    assert.dom(".inline-channel-form").exists("it displays the inline form");

    await fillIn(".inline-channel-form input", "#random");

    await click(".inline-channel-form .btn-primary");

    assert
      .dom(".channel-title .inline-channel-form")
      .doesNotExist("form closes on save");
  });

  test("Create rule works", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");

    assert.dom(".channel-footer button").exists("create button is displayed");

    await click(".channel-footer button");

    assert
      .dom("#chat-integration-edit-rule-modal")
      .exists("modal opens on edit");
    assert.dom("#save-rule").isEnabled();

    await click("#save-rule");

    assert
      .dom("#chat-integration-edit-rule-modal")
      .doesNotExist("modal closes on save");
  });

  test("Edit rule works", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");

    assert.dom(".edit").exists("edit button is displayed");

    await click(".edit");

    assert
      .dom("#chat-integration-edit-rule-modal")
      .exists("modal opens on edit");
    assert.dom("#save-rule").isEnabled();

    await click("#save-rule");

    assert
      .dom("#chat-integration-edit-rule-modal")
      .doesNotExist("modal closes on save");
  });

  test("Delete channel works", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");

    // Open the channel actions dropdown menu and click delete
    await click(".channel-header .fk-d-menu__trigger");
    await click(".delete-channel");

    assert.dom("div.dialog-content").exists("dialog is displayed");
    await click("div.dialog-content .btn-danger");

    assert.dom("div.dialog-content").doesNotExist("dialog has closed");
  });

  test("Delete rule works", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");

    assert.dom(".delete").exists();
    await click(".delete");
  });

  test("Test channel works", async function (assert) {
    await visit("/admin/plugins/discourse-chat-integration/providers/dummy");

    // Open the channel actions dropdown menu and click test
    await click(".channel-header .fk-d-menu__trigger");
    await click(".test-channel");

    assert.dom("#chat-integration-test-modal").exists("it displays the modal");
    assert.dom("#send-test").isDisabled();

    await fillIn("#choose-topic-title", "9318");
    await click("#chat-integration-test-modal .radio");

    assert.dom("#send-test").isEnabled();

    await click("#send-test");

    assert
      .dom("#chat-integration-test-modal")
      .exists("modal doesn't close on send");
    assert
      .dom("#chat-integration-test-modal .alert-success")
      .exists("success message displayed");
  });
});
