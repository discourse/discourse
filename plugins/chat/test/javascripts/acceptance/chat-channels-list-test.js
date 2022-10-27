import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import { directMessageChannels } from "discourse/plugins/chat/chat-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

acceptance(
  "Discourse Chat - Chat Channels list - no joinable public channels",
  function (needs) {
    needs.user({ has_chat_enabled: true, has_joinable_public_channels: false });

    needs.settings({
      chat_enabled: true,
    });

    needs.pretender((server, helper) => {
      server.get("/chat/chat_channels.json", () => {
        return helper.response({
          public_channels: [],
          direct_message_channels: cloneJSON(directMessageChannels).mapBy(
            "chat_channel"
          ),
        });
      });

      server.get("/chat/:id/messages.json", () => {
        return helper.response({
          chat_messages: [],
          meta: { can_chat: true },
        });
      });
    });

    test("Public chat channels section visibility", async function (assert) {
      await visit("/chat");

      assert.ok(
        exists(".public-channels-section"),
        "it shows the section for staff"
      );

      updateCurrentUser({ admin: false, moderator: false });

      assert.notOk(
        exists(".public-channels-section"),
        "it doesn’t show the section for regular user"
      );
    });
  }
);
