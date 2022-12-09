import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { ORIGINS } from "discourse/plugins/chat/discourse/services/chat-channel-info-route-origin-manager";
import { getOwner } from "discourse-common/lib/get-owner";
import fabricators from "../helpers/fabricators";

acceptance("Discourse Chat - chat channel info", function (needs) {
  needs.user({ has_chat_enabled: true, can_chat: true });

  needs.settings({ chat_enabled: true });

  needs.pretender((server, helper) => {
    const channel = fabricators.chatChannel();
    server.get("/chat/chat_channels.json", () => {
      return helper.response({
        public_channels: [],
        direct_message_channels: [],
        message_bus_last_ids: {
          channel_metadata: 0,
          channel_edits: 0,
          channel_status: 0,
          new_channel: 0,
          user_tracking_state: 0,
        },
      });
    });
    server.get("/chat/chat_channels/:id.json", () => {
      return helper.response(channel);
    });
    server.get("/chat/api/chat_channels.json", () =>
      helper.response([channel])
    );
    server.get("/chat/api/chat_channels/:id/memberships.json", () =>
      helper.response([])
    );
    server.get("/chat/:id/messages.json", () =>
      helper.response({ chat_messages: [], meta: {} })
    );
  });

  needs.hooks.beforeEach(function () {
    this.manager = getOwner(this).lookup(
      "service:chat-channel-info-route-origin-manager"
    );
  });

  needs.hooks.afterEach(function () {
    this.manager.origin = null;
  });

  test("Direct visit sets origin as channel", async function (assert) {
    await visit("/chat/channel/1/my-category-title/info");

    assert.strictEqual(this.manager.origin, ORIGINS.channel);
  });

  test("Visit from browse sets origin as browse", async function (assert) {
    await visit("/chat/browse/open");
    await click(".chat-channel-card__setting");

    assert.strictEqual(this.manager.origin, ORIGINS.browse);
  });

  test("Visit from channel sets origin as channel", async function (assert) {
    await visit("/chat/channel/1/my-category-title");
    await visit("/chat/channel/1/my-category-title/info");

    assert.strictEqual(this.manager.origin, ORIGINS.channel);
  });
});
