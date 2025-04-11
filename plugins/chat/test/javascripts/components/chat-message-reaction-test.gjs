import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";

module("Discourse Chat | Component | chat-message-reaction", function (hooks) {
  setupRenderingTest(hooks);

  test("adds reacted class when user reacted", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart" reacted=true}} />
      </template>
    );

    assert.dom(".chat-message-reaction.reacted").exists();
  });

  test("adds reaction name as class", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart"}} />
      </template>
    );

    assert.dom(`.chat-message-reaction[data-emoji-name="heart"]`).exists();
  });

  test("title/alt attributes", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart"}} />
      </template>
    );

    assert.dom(".chat-message-reaction").hasAttribute("title", ":heart:");
    assert.dom(".chat-message-reaction img").hasAttribute("alt", ":heart:");
  });

  test("count of reactions", async function (assert) {
    const self = this;

    this.set("count", 0);

    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart" count=self.count}}
        />
      </template>
    );

    assert.dom(".chat-message-reaction .count").doesNotExist();

    this.set("count", 2);
    assert.dom(".chat-message-reaction .count").hasText("2");
  });

  test("reaction’s image", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart"}} />
      </template>
    );

    assert.dom(".chat-message-reaction img").hasAttribute("src", /heart\.png/);
  });

  test("click action", async function (assert) {
    const self = this;

    this.set("count", 0);
    this.set("react", () => {
      this.set("count", 1);
    });

    await render(
      <template>
        <ChatMessageReaction
          class="show"
          @reaction={{hash emoji="heart" count=self.count}}
          @onReaction={{self.react}}
        />
      </template>
    );

    assert.dom(".chat-message-reaction .count").doesNotExist();

    await click(".chat-message-reaction");
    assert.dom(".chat-message-reaction .count").hasText("1");
  });
});
