import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatEmojiAvatar from "discourse/plugins/chat/discourse/components/chat-emoji-avatar";

module("Discourse Chat | Component | chat-emoji-avatar", function (hooks) {
  setupRenderingTest(hooks);

  test("uses an emoji as avatar", async function (assert) {
    const self = this;

    this.set("emoji", ":otter:");

    await render(
      <template><ChatEmojiAvatar @emoji={{self.emoji}} /></template>
    );

    assert
      .dom(
        ".chat-emoji-avatar .chat-emoji-avatar-container .emoji[title=otter]"
      )
      .exists();
  });
});
