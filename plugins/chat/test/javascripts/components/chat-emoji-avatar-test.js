import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

module("Discourse Chat | Component | chat-emoji-avatar", function (hooks) {
  setupRenderingTest(hooks);

  test("uses an emoji as avatar", async function (assert) {
    this.set("emoji", ":otter:");

    await render(hbs`<ChatEmojiAvatar @emoji={{this.emoji}} />`);

    assert.true(
      exists(
        `.chat-emoji-avatar .chat-emoji-avatar-container .emoji[title=otter]`
      )
    );
  });
});
