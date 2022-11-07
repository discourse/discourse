import { setCaretPosition } from "discourse/lib/utilities";
import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { chatChannelPretender } from "../helpers/chat-pretenders";
import { fillIn, settled, triggerKeyEvent, visit } from "@ember/test-helpers";

acceptance(
  "Discourse Chat - Composer hashtag autocompletion",
  function (needs) {
    needs.user({
      admin: false,
      moderator: false,
      username: "eviltrout",
      id: 100,
      can_chat: true,
      has_chat_enabled: true,
    });
    needs.pretender((server, helper) => {
      chatChannelPretender(server, helper);
      server.get("/chat/:id/messages.json", () =>
        helper.response({ chat_messages: [], meta: {} })
      );
      server.post("/chat/drafts", () => helper.response(500, {}));
      server.get("/hashtags/search.json", () => {
        return helper.response({
          results: [
            { type: "category", text: "Design", slug: "design", ref: "design" },
            { type: "tag", text: "dev", slug: "dev", ref: "dev" },
            { type: "tag", text: "design", slug: "design", ref: "design::tag" },
          ],
        });
      });
    });
    needs.settings({
      chat_enabled: true,
      enable_experimental_hashtag_autocomplete: true,
    });

    test("using # in the chat composer shows category and tag autocomplete options", async function (assert) {
      await visit("/chat/channel/11/-");
      const composerInput = query(".chat-composer-input");
      await fillIn(".chat-composer-input", "abc #");
      await triggerKeyEvent(".chat-composer-input", "keydown", "#");
      await fillIn(".chat-composer-input", "abc #");
      await setCaretPosition(composerInput, 5);
      await triggerKeyEvent(".chat-composer-input", "keyup", "#");
      await triggerKeyEvent(".chat-composer-input", "keydown", "D");
      await fillIn(".chat-composer-input", "abc #d");
      await setCaretPosition(composerInput, 6);
      await triggerKeyEvent(".chat-composer-input", "keyup", "D");
      await settled();
      assert.ok(
        exists(".hashtag-autocomplete"),
        "hashtag autocomplete menu appears"
      );
      assert.strictEqual(
        queryAll(".hashtag-autocomplete__option").length,
        3,
        "all options should be shown"
      );
    });
  }
);
