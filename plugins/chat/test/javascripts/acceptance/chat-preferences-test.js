import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { chatChannels } from "discourse/plugins/chat/chat-fixtures";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { CHAT_SOUNDS } from "discourse/plugins/chat/discourse/services/chat-audio-manager";

function preferencesPretender(server, helper) {
  server.get("/u/eviltrout/activity.json", () => helper.response({}));
  server.get("/chat/chat_channels.json", () => helper.response(chatChannels));
}

acceptance("Discourse Chat | User Preferences", function (needs) {
  needs.user({ can_chat: true, has_chat_enabled: true });
  needs.settings({ chat_enabled: true });
  needs.pretender(preferencesPretender);

  test("when user has not chat sound set", async function (assert) {
    const sounds = Object.keys(CHAT_SOUNDS);
    await visit("/u/eviltrout/preferences/chat");
    const dropdown = selectKit("#user_chat_sounds");

    assert.strictEqual(dropdown.header().value(), null, "it displays no sound");

    await dropdown.expand();
    await dropdown.selectRowByValue(sounds[1]);

    assert.strictEqual(
      dropdown.header().value(),
      sounds[1],
      "it selects the sound"
    );
  });
});
