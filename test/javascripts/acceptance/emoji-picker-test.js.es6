import { acceptance } from "helpers/qunit-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji";
import { resetCache } from "discourse/components/emoji-picker";

acceptance("EmojiPicker", {
  loggedIn: true,
  beforeEach() {
    resetCache();
  }
});

QUnit.test("emoji picker can be opened/closed", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");
  andThen(() => {
    assert.notEqual(
      find(".emoji-picker")
        .html()
        .trim(),
      "",
      "it opens the picker"
    );
  });

  click("button.emoji.btn");
  andThen(() => {
    assert.equal(
      find(".emoji-picker")
        .html()
        .trim(),
      "",
      "it closes the picker"
    );
  });
});

QUnit.test("emojis can be hovered to display info", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");
  andThen(() => {
    $(".emoji-picker button[title='grinning']").trigger("mouseover");
    andThen(() => {
      assert.equal(
        find(".emoji-picker .info")
          .html()
          .trim(),
        `<img src=\"/images/emoji/emoji_one/grinning.png?v=${v}\" class=\"emoji\"> <span>:grinning:<span></span></span>`,
        "it displays emoji info when hovering emoji"
      );
    });
  });
});

QUnit.test("emoji picker triggers event when picking emoji", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");

  click(".emoji-picker button[title='grinning']");
  andThen(() => {
    assert.equal(
      find(".d-editor-input").val(),
      ":grinning:",
      "it adds the emoji code in the editor when selected"
    );
  });
});

QUnit.test("emoji picker has a list of recently used emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");

  click(
    ".emoji-picker .section[data-section='people'] button.emoji[title='grinning']"
  );
  andThen(() => {
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
  });

  click(".emoji-picker .clear-recent");
  andThen(() => {
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
});

QUnit.test("emoji picker correctly orders recently used emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");
  andThen(() => {
    click(".emoji-picker button[title='sunglasses']");
    click(".emoji-picker button[title='grinning']");
    andThen(() => {
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
    });
  });
});

QUnit.test("emoji picker lazy loads emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");

  andThen(() => {
    assert.equal(
      find('.emoji-picker button[title="massage_woman"]').css(
        "background-image"
      ),
      "none",
      "it doesn't load invisible emojis"
    );
  });
});

QUnit.test("emoji picker persists state", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");
  andThen(() => {
    click(".emoji-picker a.diversity-scale.medium-dark");
  });
  click("button.emoji.btn");

  click("button.emoji.btn");
  andThen(() => {
    assert.equal(
      find(".emoji-picker .diversity-scale.medium-dark").hasClass("selected"),
      true,
      "it stores diversity scale"
    );
  });
});
