import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import pretender from "discourse/tests/helpers/create-pretender";
import { click, fillIn, render, triggerKeyEvent } from "@ember/test-helpers";

function emojisResponse() {
  return {
    favorites: [
      {
        name: "grinning",
        tonable: false,
        url: "/images/emoji/twitter/grinning.png?v=12",
        group: "smileys_\u0026_emotion",
        search_aliases: ["smiley_cat", "star_struck"],
      },
    ],
    "smileys_&_emotion": [
      {
        name: "grinning",
        tonable: false,
        url: "/images/emoji/twitter/grinning.png?v=12",
        group: "smileys_\u0026_emotion",
        search_aliases: ["smiley_cat", "star_struck"],
      },
    ],
    "people_&_body": [
      {
        name: "raised_hands",
        tonable: true,
        url: "/images/emoji/twitter/raised_hands.png?v=12",
        group: "people_&_body",
        search_aliases: [],
      },
      {
        name: "man_rowing_boat",
        tonable: true,
        url: "/images/emoji/twitter/man_rowing_boat.png?v=12",
        group: "people_&_body",
        search_aliases: [],
      },
    ],
    objects: [
      {
        name: "womans_clothes",
        tonable: false,
        url: "/images/emoji/twitter/womans_clothes.png?v=12",
        group: "objects",
        search_aliases: [],
      },
    ],
  };
}

module("Discourse Chat | Component | chat-emoji-picker", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    this.emojiReactionStore.diversity = 1;
  });

  hooks.beforeEach(function () {
    pretender.get("/chat/emojis.json", () => {
      return [200, {}, emojisResponse()];
    });

    this.chatEmojiPickerManager = this.container.lookup(
      "service:chat-emoji-picker-manager"
    );
    this.chatEmojiPickerManager.open(() => {});
    this.chatEmojiPickerManager.addVisibleSections([
      "smileys_&_emotion",
      "people_&_body",
      "objects",
    ]);

    this.emojiReactionStore = this.container.lookup(
      "service:chat-emoji-reaction-store"
    );
  });

  test("When displaying navigation", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);

    assert.true(
      exists(
        `.chat-emoji-picker__section-btn.active[data-section="favorites"]`
      ),
      "it renders first section as active"
    );
    assert.true(
      exists(
        `.chat-emoji-picker__section-btn[data-section="smileys_&_emotion"]`
      )
    );
    assert.true(
      exists(`.chat-emoji-picker__section-btn[data-section="people_&_body"]`)
    );
    assert.true(
      exists(`.chat-emoji-picker__section-btn[data-section="objects"]`)
    );
  });

  test("When changing tone scale", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);
    await click(".chat-emoji-picker__fitzpatrick-modifier-btn.current.t1");
    await click(".chat-emoji-picker__fitzpatrick-modifier-btn.t6");

    assert.true(
      exists(`img[src="/images/emoji/twitter/raised_hands/6.png"]`),
      "it applies the tone to emojis"
    );
    assert.true(
      exists(".chat-emoji-picker__fitzpatrick-modifier-btn.current.t6"),
      "it changes the current scale to t6"
    );
  });

  test("When requesting section", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);

    assert.strictEqual(
      document.querySelector("#ember-testing-container").scrollTop,
      0
    );

    await click(`.chat-emoji-picker__section-btn[data-section="objects"]`);

    assert.true(
      document.querySelector("#ember-testing-container").scrollTop > 0,
      "it scrolls to the section"
    );
  });

  test("When filtering emojis", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);
    await fillIn(".dc-filter-input", "grinning");

    assert.strictEqual(
      queryAll(".chat-emoji-picker__section.filtered > img").length,
      1,
      "it filters the emojis list"
    );
    assert.true(
      exists('.chat-emoji-picker__section.filtered > img[alt="grinning"]'),
      "it filters the correct emoji"
    );

    await fillIn(".dc-filter-input", "Grinning");

    assert.true(
      exists('.chat-emoji-picker__section.filtered > img[alt="grinning"]'),
      "it is case insensitive"
    );

    await fillIn(".dc-filter-input", "smiley_cat");

    assert.true(
      exists('.chat-emoji-picker__section.filtered > img[alt="grinning"]'),
      "it filters the correct emoji using search alias"
    );
  });

  test("When selecting an emoji", async function (assert) {
    let selection;
    this.didSelectEmoji = (emoji) => {
      selection = emoji;
    };

    await render(
      hbs`<ChatEmojiPicker @didSelectEmoji={{this.didSelectEmoji}} />`
    );
    await click('img.emoji[data-emoji="grinning"]');

    assert.strictEqual(selection, "grinning");
  });

  test("When navigating sections", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "grinning",
      "ArrowDown focuses on the first favorite emoji"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "raised_hands",
      "ArrowDown focuses on the first emoji form the third section"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "man_rowing_boat",
      "ArrowRight focuses on the emoji at the right"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "raised_hands",
      "ArrowLeft focuses on the emoji at the left"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "grinning",
      "ArrowUp focuses on the first emoji form the second section"
    );
  });

  test("When navigating filtered emojis", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);
    await fillIn(".dc-filter-input", "man");

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "man_rowing_boat",
      "ArrowDown focuses on the first filtered emoji"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "womans_clothes",
      "ArrowRight focuses on the emoji at the right"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert.strictEqual(
      document.activeElement.dataset.emoji,
      "man_rowing_boat",
      "ArrowLeft focuses on the emoji at the left"
    );
  });

  test("When selecting a toned an emoji", async function (assert) {
    let selection;
    this.didSelectEmoji = (emoji) => {
      selection = emoji;
    };

    await render(
      hbs`<ChatEmojiPicker @didSelectEmoji={{this.didSelectEmoji}} />`
    );
    this.emojiReactionStore.diversity = 1;
    await click('img.emoji[data-emoji="man_rowing_boat"]');

    assert.strictEqual(selection, "man_rowing_boat");

    this.emojiReactionStore.diversity = 2;
    await click('img.emoji[data-emoji="man_rowing_boat"]');

    assert.strictEqual(selection, "man_rowing_boat:t2");
  });

  test("When opening the picker", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);

    assert.true(document.activeElement.classList.contains("dc-filter-input"));
  });

  test("When hovering an emoji", async function (assert) {
    await render(hbs`<ChatEmojiPicker />`);

    assert.strictEqual(
      query(
        '.chat-emoji-picker__section[data-section="people_&_body"] img.emoji:nth-child(1)'
      ).title,
      ":raised_hands:",
      "first emoji has a title"
    );

    assert.strictEqual(
      query(
        '.chat-emoji-picker__section[data-section="people_&_body"] img.emoji:nth-child(2)'
      ).title,
      ":man_rowing_boat:",
      "second emoji has a title"
    );

    await fillIn(".dc-filter-input", "grinning");
    assert.strictEqual(
      query('img.emoji[data-emoji="grinning"]').title,
      ":grinning:",
      "filtered emoji have a title"
    );

    this.emojiReactionStore.diversity = 1;
    await render(hbs`<ChatEmojiPicker />`);

    assert.strictEqual(
      query('img.emoji[data-emoji="man_rowing_boat"]').title,
      ":man_rowing_boat:",
      "it has a title without the scale as diversity value is 1"
    );

    this.emojiReactionStore.diversity = 2;
    await render(hbs`<ChatEmojiPicker />`);

    assert.strictEqual(
      query('img.emoji[data-emoji="man_rowing_boat"]').title,
      ":man_rowing_boat:t2:",
      "it has a title with the scale"
    );
  });
});
