import { click, render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";

module("Discourse Chat | Component | chat-message-reaction", function (hooks) {
  setupRenderingTest(hooks);

  test("adds reacted class when user reacted", async function (assert) {
    await render(hbs`
      <ChatMessageReaction @reaction={{hash emoji="heart" reacted=true}} />
    `);

    assert.true(exists(".chat-message-reaction.reacted"));
  });

  test("adds reaction name as class", async function (assert) {
    await render(hbs`<ChatMessageReaction @reaction={{hash emoji="heart"}} />`);

    assert.true(exists(`.chat-message-reaction[data-emoji-name="heart"]`));
  });

  test("title/alt attributes", async function (assert) {
    await render(hbs`<ChatMessageReaction @reaction={{hash emoji="heart"}} />`);

    assert.dom(".chat-message-reaction").hasAttribute("title", ":heart:");
    assert.dom(".chat-message-reaction img").hasAttribute("alt", ":heart:");
  });

  test("count of reactions", async function (assert) {
    this.set("count", 0);

    await render(hbs`
      <ChatMessageReaction @reaction={{hash emoji="heart" count=this.count}} />
    `);

    assert.false(exists(".chat-message-reaction .count"));

    this.set("count", 2);
    assert.dom(".chat-message-reaction .count").hasText("2");
  });

  test("reaction’s image", async function (assert) {
    await render(hbs`<ChatMessageReaction @reaction={{hash emoji="heart"}} />`);

    const src = query(".chat-message-reaction img").src;
    assert.true(/heart\.png/.test(src));
  });

  test("click action", async function (assert) {
    this.set("count", 0);
    this.set("react", () => {
      this.set("count", 1);
    });

    await render(hbs`
      <ChatMessageReaction class="show" @reaction={{hash emoji="heart" count=this.count}} @onReaction={{this.react}} />
    `);

    assert.false(exists(".chat-message-reaction .count"));

    await click(".chat-message-reaction");
    assert.dom(".chat-message-reaction .count").hasText("1");
  });
});
