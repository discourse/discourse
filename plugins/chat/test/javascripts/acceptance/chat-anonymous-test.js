import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Chat | Anonymous", function (needs) {
  needs.settings({
    chat_enabled: true,
    enable_public_channels: true,
    chat_allowed_groups: "4", // anonymous_users auto group
  });

  needs.hooks.beforeEach(function () {
    pretender.get("/chat/api/me/channels", () =>
      response({
        direct_message_channels: [],
        public_channels: [],
        meta: { message_bus_last_ids: {} },
        tracking: { channel_tracking: {}, thread_tracking: {} },
      })
    );
  });

  test("direct messages redirects anonymous users to public channels", async function (assert) {
    await visit("/chat/direct-messages");

    assert.strictEqual(
      currentURL(),
      "/chat/channels",
      "redirects to public channels"
    );
  });

  test("new message redirects anonymous users to public channels", async function (assert) {
    try {
      await visit("/chat/new-message");
    } catch (error) {
      assert.strictEqual(
        error.message,
        "TransitionAborted",
        "it aborts the transition"
      );
    }

    assert.strictEqual(
      currentURL(),
      "/chat/channels",
      "redirects to public channels"
    );
  });

  test("search redirects anonymous users to public channels", async function (assert) {
    await visit("/chat/search");

    assert.strictEqual(
      currentURL(),
      "/chat/channels",
      "redirects to public channels"
    );
  });

  test("starred channels redirects anonymous users to public channels", async function (assert) {
    try {
      await visit("/chat/starred-channels");
    } catch (error) {
      assert.strictEqual(
        error.message,
        "TransitionAborted",
        "it aborts the transition"
      );
    }

    assert.strictEqual(
      currentURL(),
      "/chat/channels",
      "redirects to public channels"
    );
  });

  test("threads redirects anonymous users to public channels", async function (assert) {
    await visit("/chat/threads");

    assert.strictEqual(
      currentURL(),
      "/chat/channels",
      "redirects to public channels"
    );
  });
});
