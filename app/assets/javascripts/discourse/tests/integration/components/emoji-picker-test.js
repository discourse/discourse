import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, skip, test } from "qunit";
import emojisFixtures from "discourse/tests/fixtures/emojis-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";

module("Integration | Component | emoji-picker-content", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis.json", () =>
      response(emojisFixtures["/emojis.json"])
    );

    this.emojiStore = this.container.lookup("service:emoji-store");
  });

  hooks.afterEach(function () {
    this.emojiStore.diversity = 1;
  });

  test("When displaying navigation", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom(`.emoji-picker__section-btn.active[data-section="favorites"]`)
      .exists("it renders favorites section");
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
    await emojiPicker(".emoji-picker").tone(6);

    assert
      .dom(`img[src="/images/emoji/twitter/raised_hands/6.png"]`)
      .exists("it applies the tone to emojis");
    assert
      .dom(".emoji-picker__diversity-trigger img[title='clap:t6']")
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
      .exists({ count: 2 }, "it filters the emojis list");
    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning"]')
      .exists("it filters the correct emoji");

    await fillIn(".filter-input", "Grinning");

    assert
      .dom('.emoji-picker__section.filtered > img[alt="grinning"]')
      .exists("it is case insensitive");

    await fillIn(".filter-input", "grinning");

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

  skip("When navigating sections", async function (assert) {
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
      .hasAttribute("data-emoji", "raised_hands");

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
    assert.dom(document.activeElement).hasAttribute("data-emoji", "grinning");
  });

  skip("When navigating filtered emojis", async function (assert) {
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
    const picker = emojiPicker(".emoji-picker");
    await picker.select("raised_hands");
    await picker.tone(2);
    await picker.select("raised_hands");

    assert.verifySteps(["raised_hands", "raised_hands:t2"]);
  });

  test("When hovering an emoji", async function (assert) {
    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom(
        '.emoji-picker__section[data-section="people_&_body"] img.emoji:nth-child(1)'
      )
      .hasAttribute("title", ":raised_hands:", "first emoji has a title");

    await emojiPicker(".emoji-picker").fill("grinning");

    assert
      .dom('img.emoji[data-emoji="grinning"]')
      .hasAttribute("title", ":grinning:", "filtered emoji have a title");

    await emojiPicker(".emoji-picker").tone(1);
    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom('img.emoji[data-emoji="raised_hands"]')
      .hasAttribute(
        "title",
        ":raised_hands:",
        "it has a title without the scale as diversity value is 1"
      );

    await emojiPicker(".emoji-picker").tone(2);
    await render(hbs`<EmojiPicker::Content />`);

    assert
      .dom('img.emoji[data-emoji="raised_hands"]')
      .hasAttribute(
        "title",
        ":raised_hands:t2:",
        "it has a title with the scale"
      );
  });
});
