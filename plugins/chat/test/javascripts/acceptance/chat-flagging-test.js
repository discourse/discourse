import selectKit from "discourse/tests/helpers/select-kit-helper";
import {
  acceptance,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import {
  chatChannels,
  generateChatView,
} from "discourse/plugins/chat/chat-fixtures";
import { test } from "qunit";
import { click, triggerEvent, visit } from "@ember/test-helpers";

acceptance("Discourse Chat - Flagging test", function (needs) {
  let defaultChatView;
  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 100,
    can_chat: true,
    has_chat_enabled: true,
  });
  needs.pretender((server, helper) => {
    server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
    server.get("/chat/9/messages.json", () => {
      return helper.response(
        generateChatView(loggedInUser(), {
          can_flag: false,
        })
      );
    });
    server.get("/chat/75/messages.json", () => {
      defaultChatView = generateChatView(loggedInUser());
      return helper.response(defaultChatView);
    });
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
    server.put("/chat/flag", () => {
      return helper.response({ success: true });
    });
  });
  needs.settings({
    chat_enabled: true,
  });

  test("Flagging in public channel works", async function (assert) {
    await visit("/chat/channel/75/site");

    assert.notOk(exists(".chat-live-pane .chat-message .chat-message-flagged"));
    await triggerEvent(".chat-message-container", "mouseenter");

    const moreButtons = selectKit(
      ".chat-message-actions-container .more-buttons"
    );
    await moreButtons.expand();

    const content = moreButtons.displayedContent();
    assert.ok(content.find((row) => row.id === "flag"));

    await moreButtons.selectRowByValue("flag");

    await click(".controls.spam input");
    await click(".modal-footer button");

    await publishToMessageBus("/chat/75", {
      type: "self_flagged",
      chat_message_id: defaultChatView.chat_messages[0].id,
      user_flag_status: 0,
    });
    await publishToMessageBus("/chat/75", {
      type: "flag",
      chat_message_id: defaultChatView.chat_messages[0].id,
      reviewable_id: 1,
    });

    const reviewableLink = query(
      `.chat-message-container[data-id='${defaultChatView.chat_messages[0].id}'] .chat-message-info__flag a`
    );
    assert.ok(reviewableLink.href.endsWith("/review/1"));
  });

  test("Flag button isn't present for DM channel", async function (assert) {
    await visit("/chat/channel/9/@hawk");
    await triggerEvent(".chat-message-container", "mouseenter");

    const moreButtons = selectKit(".chat-message-actions .more-buttons");
    await moreButtons.expand();

    const content = moreButtons.displayedContent();
    assert.notOk(content.find((row) => row.id === "flag"));
  });
});
