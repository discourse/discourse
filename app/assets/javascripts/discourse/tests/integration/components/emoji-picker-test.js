import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import emojisFixtures from "discourse/tests/fixtures/emojis-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Discourse Chat | Component | emoji-picker-content", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    this.emojiReactionStore.diversity = 1;
  });

  hooks.beforeEach(function () {
    pretender.get("/emojis.json", () =>
      response(emojisFixtures["/emojis.json"])
    );

    this.emojiReactionStore = this.container.lookup(
      "service:emoji-reaction-store"
    );
  });

  test("When displaying navigation", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom(`.emoji-picker__section-btn.active[data-section="favorites"]`)
      .exists("it renders first section as active");
    assert
      .dom(`.emoji-picker__section-btn[data-section="smileys_&_emotion"]`)
      .exists();
    assert
      .dom(`.emoji-picker__section-btn[data-section="people_&_body"]`)
      .exists();
    assert.dom(`.emoji-picker__section-btn[data-section="objects"]`).exists();
  });

  test("When changing tone scale", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);
    await click(".emoji-picker__fitzpatrick-modifier-btn.current.t1");
    await click(".emoji-picker__fitzpatrick-modifier-btn.t6");

    assert
      .dom(`img[src="/images/emoji/twitter/raised_hands/6.png"]`)
      .exists("it applies the tone to emojis");
    assert
      .dom(".emoji-picker__fitzpatrick-modifier-btn.current.t6")
      .exists("it changes the current scale to t6");
  });

  test("When requesting section", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);

    assert.strictEqual(
      document.querySelector("#ember-testing-container").scrollTop,
      0
    );

    await click(`.emoji-picker__section-btn[data-section="objects"]`);

    assert.true(
      document.querySelector(".emoji-picker__scrollable-content").scrollTop > 0,
      "it scrolls to the section"
    );
  });

  test("When filtering emojis", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);
    await fillIn(".filter-input", "grinning");

    assert
      .dom(".emoji-picker__section.filtered > img")
      .exists({ count: 1 }, "it filters the emojis list");
    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning"]')
      .exists("it filters the correct emoji");

    await fillIn(".filter-input", "Grinning");

    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning"]')
      .exists("it is case insensitive");

    await fillIn(".filter-input", "smiley_cat");

    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning"]')
      .exists("it filters the correct emoji using search alias");
  });

  test("When selecting an emoji", async function (assert) {
    this.didSelectEmoji = (emoji) => assert.step(emoji);

    await render(
      hbs`<EmojiPicker::Content @didSelectEmoji={{this.didSelectEmoji}} />`
    );
    await click('img.emoji[data-emoji="grinning"]');

    assert.verifySteps(["grinning"]);
  });

  test("When navigating sections", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "grinning",
        "ArrowDown focuses on the first favorite emoji"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "raised_hands",
        "ArrowDown focuses on the first emoji form the third section"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "man_rowing_boat",
        "ArrowRight focuses on the emoji at the right"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "raised_hands",
        "ArrowLeft focuses on the emoji at the left"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "grinning",
        "ArrowUp focuses on the first emoji form the second section"
      );
  });

  test("When navigating filtered emojis", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);
    await fillIn(".filter-input", "man");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "man_rowing_boat",
        "ArrowDown focuses on the first filtered emoji"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "womans_clothes",
        "ArrowRight focuses on the emoji at the right"
      );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert
      .dom(document.activeElement)
      .hasAttribute(
        "data-emoji",
        "man_rowing_boat",
        "ArrowLeft focuses on the emoji at the left"
      );
  });

  test("When selecting a toned an emoji", async function (assert) {
    this.didSelectEmoji = (emoji) => assert.step(emoji);

    await render(
      hbs`<EmojiPicker::Content @didSelectEmoji={{this.didSelectEmoji}} />`
    );
    this.emojiReactionStore.diversity = 1;
    await click('img.emoji[data-emoji="man_rowing_boat"]');

    this.emojiReactionStore.diversity = 2;
    await click('img.emoji[data-emoji="man_rowing_boat"]');

    assert.verifySteps(["man_rowing_boat", "man_rowing_boat:t2"]);
  });

  test("When hovering an emoji", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom(
        '.emoji-picker__section[data-section="people_&_body"] img.emoji:nth-child(1)'
      )
      .hasAttribute("title", ":raised_hands:", "first emoji has a title");

    assert
      .dom(
        '.emoji-picker__section[data-section="people_&_body"] img.emoji:nth-child(2)'
      )
      .hasAttribute("title", ":man_rowing_boat:", "second emoji has a title");

    await fillIn(".filter-input", "grinning");

    assert
      .dom('img.emoji[data-emoji="grinning"]')
      .hasAttribute("title", ":grinning:", "filtered emoji have a title");

    this.emojiReactionStore.diversity = 1;

    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom('img.emoji[data-emoji="man_rowing_boat"]')
      .hasAttribute(
        "title",
        ":man_rowing_boat:",
        "it has a title without the scale as diversity value is 1"
      );

    this.emojiReactionStore.diversity = 2;
    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom('img.emoji[data-emoji="man_rowing_boat"]')
      .hasAttribute(
        "title",
        ":man_rowing_boat:t2:",
        "it has a title with the scale"
      );
  });
});
