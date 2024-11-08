import { click, visit } from "@ember/test-helpers";
import { skip } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Discourse Chat - Chat live pane - handling 429 errors",
  function (needs) {
    needs.user({
      username: "eviltrout",
      id: 1,
      has_chat_enabled: true,
    });
    needs.settings({
      chat_enabled: true,
      navigation_menu: "legacy",
    });

    needs.pretender((server, helper) => {
      server.get("/chat/:chatChannelId/messages.json", () => {
        return helper.response(429);
      });

      server.get("/chat/chat_channels.json", () =>
        helper.response({
          public_channels: [
            {
              id: 1,
              title: "something",
              current_user_membership: { following: true },
              message_bus_last_ids: { new_mentions: 0, new_messages: 0 },
            },
          ],
          direct_message_channels: [],
          message_bus_last_ids: {
            channel_metadata: 0,
            channel_edits: 0,
            channel_status: 0,
            new_channel: 0,
            user_tracking_state: 0,
          },
        })
      );

      server.get("/chat/chat_channels/:chatChannelId", () =>
        helper.response({ id: 1, title: "something" })
      );

      server.post("/chat/drafts", () => {
        return helper.response([]);
      });

      server.post("/chat/:chatChannelId.json", () => {
        return helper.response({ success: "OK" });
      });
    });

    skip("Handles 429 errors by displaying an alert", async function (assert) {
      await visit("/chat/c/cat/1");

      assert.dom(".dialog-content").exists("displays the 429 error");
      await click(".dialog-footer .btn-primary");
    });
  }
);
