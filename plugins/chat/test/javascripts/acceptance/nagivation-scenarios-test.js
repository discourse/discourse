import {
  acceptance,
  loggedInUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, visit } from "@ember/test-helpers";
import { generateChatView } from "discourse/plugins/chat/chat-fixtures";
import { test } from "qunit";
import fabricators from "../helpers/fabricators";

acceptance("Discourse Chat - Navigation scenarios", function (needs) {
  needs.user({ can_chat: true, has_chat_enabled: true });

  needs.settings({ chat_enabled: true });

  needs.pretender((server, helper) => {
    server.get("/chat/chat_channels.json", () =>
      helper.response({ public_channels: [fabricators.chatChannel()] })
    );

    server.get("/chat/:chat_channel_id/messages.json", () =>
      helper.response(generateChatView(loggedInUser()))
    );
  });

  test("Switching off full screen brings you back to previous route", async function (assert) {
    this.container.lookup("service:full-page-chat").exit();
    await visit("/t/-/280");
    await visit("/chat");

    assert.equal(currentURL(), "/chat/channel/1/my-category-title");

    await click(".chat-full-screen-button");

    assert.ok(
      currentURL().startsWith("/t/internationalization-localization/280"),
      "it redirects back to the visited topic before going full screen"
    );
  });
});
