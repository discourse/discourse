import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  count,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("EmojiPicker", function (needs) {
  needs.user();

  needs.hooks.beforeEach(function () {
    this.emojiStore = this.container.lookup("service:emoji-store");
    this.emojiStore.reset();
  });
  needs.hooks.afterEach(function () {
    this.emojiStore.reset();
  });

  test("emoji picker can be opened/closed", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await click("button.emoji.btn");
    assert.ok(exists(".emoji-picker.opened"), "it opens the picker");

    await click("button.emoji.btn");
    assert.notOk(exists(".emoji-picker.opened"), "it closes the picker");
  });

  test("filters emoji", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await fillIn(".emoji-picker input.filter", "guitar");

    assert.dom(".emoji-picker .results img").hasAttribute("title", "guitar");
  });

  test("emoji picker triggers event when picking emoji", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");

    assert.strictEqual(
      query(".d-editor-input").value,
      ":grinning:",
      "it adds the emoji code in the editor when selected"
    );
  });

  test("emoji picker adds leading whitespace before emoji", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    // Whitespace should be added on text
    await fillIn(".d-editor-input", "This is a test input");
    await click("button.emoji.btn");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");
    assert.strictEqual(
      query(".d-editor-input").value,
      "This is a test input :grinning:",
      "it adds the emoji code and a leading whitespace when there is text"
    );

    // Whitespace should not be added on whitespace
    await fillIn(".d-editor-input", "This is a test input ");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");

    assert.strictEqual(
      query(".d-editor-input").value,
      "This is a test input :grinning:",
      "it adds the emoji code and no leading whitespace when user already entered whitespace"
    );
  });

  test("emoji picker has a list of recently used emojis", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");

    assert.ok(
      exists(
        ".emoji-picker .section.recent .section-group img.emoji[title='grinning']"
      ),
      "it shows recent selected emoji"
    );

    assert
      .dom('.emoji-picker .category-button[data-section="recent"]')
      .exists("it shows recent category icon");

    await click(".emoji-picker .trash-recent");

    assert.notOk(
      exists(
        ".emoji-picker .section.recent .section-group img.emoji[title='grinning']"
      ),
      "it has cleared recent emojis"
    );

    assert
      .dom('.emoji-picker .section[data-section="recent"]')
      .doesNotExist("it hides recent section");

    assert
      .dom('.emoji-picker .category-button[data-section="recent"]')
      .doesNotExist("it hides recent category icon");
  });

  test("emoji picker correctly orders recently used emojis", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(".emoji-picker-emoji-area img.emoji[title='sunglasses']");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");

    assert.strictEqual(
      count('.section[data-section="recent"] .section-group img.emoji'),
      2,
      "it has multiple recent emojis"
    );

    assert.strictEqual(
      /grinning/.test(
        query(".section.recent .section-group img.emoji").getAttribute("src")
      ),
      true,
      "it puts the last used emoji in first"
    );
  });

  test("updates the recent list when selecting from it (after you close re-open it or select other emoji)", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(`.emoji-picker-emoji-area img.emoji[title="sunglasses"]`);
    await click(`.emoji-picker-emoji-area img.emoji[title="grinning"]`);

    let recent = queryAll(".section.recent .section-group img.emoji");
    assert.strictEqual(recent[0].title, "grinning");
    assert.strictEqual(recent[1].title, "sunglasses");

    await click(
      `.section[data-section="recent"] .section-group img.emoji[title="sunglasses"]`
    );

    // The order is still the same
    recent = queryAll(".section.recent .section-group img.emoji");
    assert.strictEqual(recent[0].title, "grinning");
    assert.strictEqual(recent[1].title, "sunglasses");

    await click("button.emoji.btn");
    await click("button.emoji.btn");

    // but updates when you re-open
    recent = queryAll(".section.recent .section-group img.emoji");
    assert.strictEqual(recent[0].title, "sunglasses");
    assert.strictEqual(recent[1].title, "grinning");
  });

  test("emoji picker persists state", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(".emoji-picker button.diversity-scale.medium-dark");
    await click("button.emoji.btn");
    await click("button.emoji.btn");

    assert
      .dom(".emoji-picker button.diversity-scale.medium-dark .d-icon")
      .exists("it stores diversity scale");
  });

  test("emoji can be selected with keyboard", async function (assert) {
    const searchInput = ".emoji-picker-search-container input";
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click(".emoji.btn");

    let emojis = document.querySelectorAll(
      ".emoji-picker-emoji-area img.emoji"
    );

    assert.strictEqual(
      document.activeElement,
      document.querySelector(searchInput),
      "search input is focused by default"
    );

    await triggerKeyEvent(searchInput, "keydown", "ArrowDown");
    assert.strictEqual(
      document.activeElement,
      emojis[0],
      "ArrowDown from search focuses on the first emoji result"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    assert.strictEqual(
      document.activeElement,
      emojis[1],
      "ArrowRight from first emoji focuses on the second emoji"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");
    assert.strictEqual(
      document.activeElement,
      emojis[0],
      "ArrowLeft from second emoji focuses on the first emoji"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    await triggerKeyEvent(document.activeElement, "keydown", "Enter");
    assert.strictEqual(
      document.querySelector(".d-editor-input").value,
      ":smiley:",
      "Pressing enter inserts the emoji markup in the composer"
    );

    await click("#topic-footer-buttons .btn.create");
    await click(".emoji.btn");
    await triggerKeyEvent(searchInput, "keydown", "ArrowDown");
    emojis = document.querySelectorAll(".emoji-picker-emoji-area img.emoji");

    assert.strictEqual(
      document.activeElement,
      document.querySelector(".emoji-picker-emoji-area .emoji.recent-emoji"),
      "ArrowDown focuses on the first emoji result (recent emoji)"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
    assert.strictEqual(
      document.activeElement,
      document.querySelector(".emojis-container .emoji[title='grinning']"),
      "ArrowDown again focuses on the first emoji result in a section"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");
    await triggerKeyEvent(document.activeElement, "keydown", "ArrowRight");

    assert.strictEqual(
      document.activeElement,
      emojis[4],
      "ArrowRight moves focus to next right element"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "ArrowUp");

    assert.strictEqual(
      document.activeElement,
      document.querySelector(searchInput),
      "ArrowUp from first row items moves focus to input"
    );
  });

  test("emoji picker can be dismissed with escape key", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await triggerKeyEvent(document.activeElement, "keydown", "Escape");
    assert.dom(".emoji-picker").doesNotExist();
    assert.strictEqual(
      document.activeElement,
      document.querySelector("textarea"),
      "escaping from emoji picker focuses back on input"
    );
  });
});
