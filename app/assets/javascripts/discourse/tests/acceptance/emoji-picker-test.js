import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("EmojiPicker", function (needs) {
  needs.user();

  needs.hooks.beforeEach(function () {
    this.emojiStore = this.container.lookup("service:emoji-store");
    this.emojiStore.reset();
  });
  needs.hooks.afterEach(function () {
    this.emojiStore.reset();
  });

  test("emoji picker can be opened/closed", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await click("button.emoji.btn");
    assert.ok(exists(".emoji-picker.opened"), "it opens the picker");

    await click("button.emoji.btn");
    assert.notOk(exists(".emoji-picker.opened"), "it closes the picker");
  });

  test("emoji picker triggers event when picking emoji", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");

    assert.equal(
      find(".d-editor-input").val(),
      ":grinning:",
      "it adds the emoji code in the editor when selected"
    );
  });

  test("emoji picker adds leading whitespace before emoji", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    // Whitespace should be added on text
    await fillIn(".d-editor-input", "This is a test input");
    await click("button.emoji.btn");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");
    assert.equal(
      find(".d-editor-input").val(),
      "This is a test input :grinning:",
      "it adds the emoji code and a leading whitespace when there is text"
    );

    // Whitespace should not be added on whitespace
    await fillIn(".d-editor-input", "This is a test input ");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");

    assert.equal(
      find(".d-editor-input").val(),
      "This is a test input :grinning:",
      "it adds the emoji code and no leading whitespace when user already entered whitespace"
    );
  });

  test("emoji picker has a list of recently used emojis", async (assert) => {
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

    assert.ok(
      exists('.emoji-picker .category-button[data-section="recent"]'),
      "it shows recent category icon"
    );

    await click(".emoji-picker .trash-recent");

    assert.notOk(
      exists(
        ".emoji-picker .section.recent .section-group img.emoji[title='grinning']"
      ),
      "it has cleared recent emojis"
    );

    assert.notOk(
      exists('.emoji-picker .section[data-section="recent"]'),
      "it hides recent section"
    );

    assert.notOk(
      exists('.emoji-picker .category-button[data-section="recent"]'),
      "it hides recent category icon"
    );
  });

  test("emoji picker correctly orders recently used emojis", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(".emoji-picker-emoji-area img.emoji[title='sunglasses']");
    await click(".emoji-picker-emoji-area img.emoji[title='grinning']");

    assert.equal(
      find('.section[data-section="recent"] .section-group img.emoji').length,
      2,
      "it has multiple recent emojis"
    );

    assert.equal(
      /grinning/.test(
        find(".section.recent .section-group img.emoji").first().attr("src")
      ),
      true,
      "it puts the last used emoji in first"
    );
  });

  test("emoji picker persists state", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await click("button.emoji.btn");
    await click(".emoji-picker button.diversity-scale.medium-dark");
    await click("button.emoji.btn");
    await click("button.emoji.btn");

    assert.ok(
      exists(".emoji-picker button.diversity-scale.medium-dark .d-icon"),
      true,
      "it stores diversity scale"
    );
  });
});
