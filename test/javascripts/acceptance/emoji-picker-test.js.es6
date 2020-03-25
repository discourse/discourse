import { acceptance } from "helpers/qunit-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";

acceptance("EmojiPicker", {
  loggedIn: true,
  beforeEach() {
    const store = Discourse.__container__.lookup("service:emoji-store");
    store.reset();
  }
});

QUnit.test("emoji picker can be opened/closed", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await click("button.emoji.btn");
  assert.notEqual(
    find(".emoji-picker")
      .html()
      .trim(),
    "",
    "it opens the picker"
  );

  await click("button.emoji.btn");
  assert.equal(
    find(".emoji-picker")
      .html()
      .trim(),
    "",
    "it closes the picker"
  );
});

QUnit.test("emojis can be hovered to display info", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await click("button.emoji.btn");
  $(".emoji-picker button[title='grinning']").trigger("mouseover");
  assert.equal(
    find(".emoji-picker .info")
      .html()
      .trim(),
    `<img src=\"/images/emoji/emoji_one/grinning.png?v=${v}\" class=\"emoji\"> <span>:grinning:<span></span></span>`,
    "it displays emoji info when hovering emoji"
  );
});

QUnit.test("emoji picker triggers event when picking emoji", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");
  await click("button.emoji.btn");

  await click(".emoji-picker button[title='grinning']");
  assert.equal(
    find(".d-editor-input").val(),
    ":grinning:",
    "it adds the emoji code in the editor when selected"
  );
});

QUnit.test(
  "emoji picker adds leading whitespace before emoji",
  async assert => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    // Whitespace should be added on text
    await fillIn(".d-editor-input", "This is a test input");
    await click("button.emoji.btn");
    await click(".emoji-picker button[title='grinning']");
    assert.equal(
      find(".d-editor-input").val(),
      "This is a test input :grinning:",
      "it adds the emoji code and a leading whitespace when there is text"
    );
    await click("button.emoji.btn");

    // Whitespace should not be added on whitespace
    await fillIn(".d-editor-input", "This is a test input ");
    await click("button.emoji.btn");
    await click(".emoji-picker button[title='grinning']");
    assert.equal(
      find(".d-editor-input").val(),
      "This is a test input :grinning:",
      "it adds the emoji code and no leading whitespace when user already entered whitespace"
    );
    await click("button.emoji.btn");
  }
);

QUnit.test("emoji picker has a list of recently used emojis", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");
  await click("button.emoji.btn");

  await click(
    ".emoji-picker .section[data-section='smileys_&_emotion'] button.emoji[title='grinning']"
  );
  assert.equal(
    find('.emoji-picker .section[data-section="recent"]').css("display"),
    "block",
    "it shows recent section"
  );

  assert.equal(
    find(
      '.emoji-picker .section[data-section="recent"] .section-group button.emoji'
    ).length,
    1,
    "it adds the emoji code to the recently used emojis list"
  );

  await click(".emoji-picker .clear-recent");
  assert.equal(
    find(
      '.emoji-picker .section[data-section="recent"] .section-group button.emoji'
    ).length,
    0,
    "it has cleared recent emojis"
  );

  assert.equal(
    find('.emoji-picker .section[data-section="recent"]').css("display"),
    "none",
    "it hides recent section"
  );

  assert.equal(
    find('.emoji-picker .category-icon button.emoji[data-section="recent"]')
      .parent()
      .css("display"),
    "none",
    "it hides recent category icon"
  );
});

QUnit.test(
  "emoji picker correctly orders recently used emojis",
  async assert => {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");

    await click("button.emoji.btn");
    await click(".emoji-picker button[title='sunglasses']");
    await click(".emoji-picker button[title='grinning']");
    assert.equal(
      find('.section[data-section="recent"] .section-group button.emoji')
        .length,
      2,
      "it has multiple recent emojis"
    );

    assert.equal(
      /grinning/.test(
        find('.section[data-section="recent"] .section-group button.emoji')
          .first()
          .css("background-image")
      ),
      true,
      "it puts the last used emoji in first"
    );
  }
);

QUnit.test("emoji picker lazy loads emojis", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await click("button.emoji.btn");

  assert.equal(
    find('.emoji-picker button[title="massage_woman"]').css("background-image"),
    "none",
    "it doesn't load invisible emojis"
  );
});

QUnit.test("emoji picker persists state", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await click("button.emoji.btn");
  await click(".emoji-picker a.diversity-scale.medium-dark");
  await click("button.emoji.btn");

  await click("button.emoji.btn");
  assert.equal(
    find(".emoji-picker .diversity-scale.medium-dark").hasClass("selected"),
    true,
    "it stores diversity scale"
  );
});
