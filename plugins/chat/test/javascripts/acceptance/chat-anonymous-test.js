import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { MAIN_PANEL } from "discourse/lib/sidebar/panels";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { CHAT_PANEL } from "discourse/plugins/chat/discourse/lib/init-sidebar-state";

acceptance("Chat | Anonymous", function (needs) {
  needs.settings({
    chat_enabled: true,
    enable_public_channels: true,
    chat_allowed_groups: "4", // anonymous_users auto group
    navigation_menu: "sidebar",
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

  test("follows the never site setting", async function (assert) {
    this.siteSettings.chat_separate_sidebar_mode = "never";

    await visit("/chat/channels");

    const sidebarState = this.container.lookup("service:sidebar-state");
    assert.true(sidebarState.combinedMode, "uses combined sidebar mode");
    assert.strictEqual(
      sidebarState.currentPanelKey,
      MAIN_PANEL,
      "keeps the main panel selected"
    );
    assert.false(
      sidebarState.displaySwitchPanelButtons,
      "hides the panel switch buttons"
    );
  });

  test("follows the always site setting", async function (assert) {
    this.siteSettings.chat_separate_sidebar_mode = "always";

    await visit("/chat/channels");

    const sidebarState = this.container.lookup("service:sidebar-state");
    assert.false(sidebarState.combinedMode, "uses separated sidebar mode");
    assert.strictEqual(
      sidebarState.currentPanelKey,
      CHAT_PANEL,
      "selects the chat panel"
    );
    assert.true(
      sidebarState.displaySwitchPanelButtons,
      "shows the panel switch buttons"
    );
  });
});
