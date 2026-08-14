import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatMessageReaction from "discourse/plugins/chat/discourse/components/chat-message-reaction";

module("Component | ChatMessageReaction", function (hooks) {
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

  test("names itself as a reaction rather than just an emoji", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction @reaction={{hash emoji="heart" count=3}} />
      </template>
    );

    assert
      .dom(".chat-message-reaction")
      .hasAria(
        "label",
        i18n("chat.reactions.counted", { emoji: "heart", count: 3 }),
        "a counted reaction is named by what it stands for"
      );
  });

  test("names itself by its action where it is only a way to react", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart"}}
          @showCount={{false}}
        />
      </template>
    );

    assert
      .dom(".chat-message-reaction")
      .hasAria("label", i18n("chat.reactions.add", { emoji: "heart" }));
  });

  test("reports whether the reaction is the current user's", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart" count=1 reacted=true}}
        />
        <ChatMessageReaction
          @reaction={{hash emoji="+1" count=1 reacted=false}}
        />
      </template>
    );

    assert.dom("[data-emoji-name='heart']").hasAria("pressed", "true");
    assert.dom("[data-emoji-name='+1']").hasAria("pressed", "false");
  });

  test("is not a toggle where it is only a way to react", async function (assert) {
    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart" reacted=true}}
          @showCount={{false}}
        />
      </template>
    );

    // named for its action, so announcing a pressed state on top of that describes
    // neither the control nor its effect
    assert.dom(".chat-message-reaction").doesNotHaveAria("pressed");
  });

  test("count of reactions", async function (assert) {
    this.set("count", 0);

    await render(
      <template>
        <ChatMessageReaction
          @reaction={{hash emoji="heart" count=this.count}}
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
    this.set("count", 0);
    this.set("react", () => {
      this.set("count", 1);
    });

    await render(
      <template>
        <ChatMessageReaction
          class="show"
          @reaction={{hash emoji="heart" count=this.count}}
          @onReaction={{this.react}}
        />
      </template>
    );

    assert.dom(".chat-message-reaction .count").doesNotExist();

    await click(".chat-message-reaction");
    assert.dom(".chat-message-reaction .count").hasText("1");
  });
});
