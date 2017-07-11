import { acceptance } from "helpers/qunit-helpers";
import { IMAGE_VERSION as v } from 'pretty-text/emoji';
import {
  keyValueStore,
  EMOJI_USAGE,
  EMOJI_SCROLL_Y,
  EMOJI_SELECTED_DIVERSITY
} from 'discourse/components/emoji-picker';

acceptance("EmojiPicker", {
  loggedIn: true,
  beforeEach() {
    keyValueStore.setObject({ key: EMOJI_USAGE, value: {} });
    keyValueStore.setObject({ key: EMOJI_SCROLL_Y, value: 0 });
    keyValueStore.setObject({ key: EMOJI_SELECTED_DIVERSITY, value: 1 });
  }
});

QUnit.test("emoji picker can be opened/closed", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");
  andThen(() => {
    assert.notEqual(
      find('.emoji-picker').html().trim(),
      "",
      "it opens the picker"
    );
  });

  click("button.emoji.btn");
  andThen(() => {
    assert.equal(
      find('.emoji-picker').html().trim(),
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
    $(".emoji-picker a[title='grinning']").trigger('mouseover');
    andThen(() => {
      assert.equal(
        find('.emoji-picker .info').html().trim(),
        `<img src=\"/images/emoji/emoji_one/grinning.png?v=${v}\" class=\"emoji\"> <span>:grinning:<span></span></span>`,
        "it displays emoji info when hovering emoji"
      );
    });
  });
});

QUnit.test("emoji picker has sections", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");

  click(".emoji-picker .categories-column a[title='travel']");
  andThen(() => {
    assert.notEqual(
      find('.emoji-picker .list').scrollTop(),
      0,
      "it scrolls to section"
    );

    assert.equal(
      find(".emoji-picker .categories-column a[title='travel']").parent().hasClass('current'),
      true,
      "it highlights section icon"
    );
  });
});

QUnit.test("emoji picker triggers event when picking emoji", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");

  click(".emoji-picker a[title='grinning']");
  andThen(() => {
    assert.equal(
      find('.d-editor-input').val(),
      ":grinning:",
      "it adds the emoji code in the editor when selected"
    );
  });
});

QUnit.test("emoji picker has a list of recently used emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");
  click(".emoji-picker .clear-recent");

  click(".emoji-picker a[title='grinning']");
  andThen(() => {
    assert.equal(
      find('.section[data-section="recent"]').css("display"),
      "block",
      "it shows recent section"
    );

    assert.equal(
      find('.section[data-section="recent"] .section-group img.emoji').length,
      1,
      "it adds the emoji code to the recently used emojis list"
    );
  });
});

QUnit.test("emoji picker can clear recently used emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");

  click(".emoji-picker a[title='grinning']");
  click(".emoji-picker a[title='sunglasses']");
  click(".emoji-picker a[title='sunglasses']");
  andThen(() => {
    assert.equal(
      find('.section[data-section="recent"] .section-group img.emoji').length,
      2
    );

    click(".emoji-picker .clear-recent");
    andThen(() => {
      assert.equal(
        find('.section[data-section="recent"] .section-group img.emoji').length,
        0,
        "it has cleared recent emojis"
      );

      assert.equal(
        find('.section[data-section="recent"]').css("display"),
        "none",
        "it hides recent section"
      );

      assert.equal(
        find('.category-icon a[title="recent"]').parent().css("display"),
        "none",
        "it hides recent category icon"
      );
    });
  });
});

QUnit.test("emoji picker correctly orders recently used emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");
  click(".emoji-picker .clear-recent");

  click(".emoji-picker a[title='grinning']");
  click(".emoji-picker a[title='sunglasses']");
  click(".emoji-picker a[title='sunglasses']");
  andThen(() => {
    assert.equal(
      find('.section[data-section="recent"] .section-group img.emoji').length,
      2,
      "it has multiple recent emojis"
    );

    assert.equal(
      find('.section[data-section="recent"] .section-group img.emoji').first().attr('src'),
      `/images/emoji/emoji_one/sunglasses.png?v=${v}`,
      "it puts the most used emoji in first"
    );
  });
});

QUnit.test("emoji picker lazy loads emojis", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");

  andThen(() => {
    const $emoji = $('.emoji-picker a[title="massage_woman"] img');
    assert.equal(
      $emoji.attr('src'),
      "",
      "it doesn't load invisible emojis"
    );
  });

  andThen(() => {
    const done = assert.async();
    setTimeout(() => {
      $('.emoji-picker .list').scrollTop(2600);
      setTimeout(() => {
        const $emoji = $('a[title="massage_woman"] img');
        assert.equal(
          $emoji.attr('src'),
          `/images/emoji/emoji_one/massage_woman.png?v=${v}`,
          "it loads visible emojis"
        );
        done();
      }, 50);
    }, 50);
  });
});

QUnit.test("emoji picker supports diversity scale", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");
  click("button.emoji.btn");

  click('.emoji-picker a.diversity-scale.dark');
  andThen(() => {
    const done = assert.async();
    setTimeout(() => {
      $('.emoji-picker .list').scrollTop(2900);
      setTimeout(() => {
        const $emoji = $('a[title="massage_woman"] img');
        assert.equal(
          $emoji.attr('src'),
          `/images/emoji/emoji_one/massage_woman/6.png?v=${v}`,
          "it applies diversity scale on emoji"
        );
        done();
      }, 250);
    }, 250);
  });
});

QUnit.test("emoji picker persists state", assert => {
  visit("/t/internationalization-localization/280");
  click("#topic-footer-buttons .btn.create");

  click("button.emoji.btn");
  andThen(() => {
    $('.emoji-picker .list').scrollTop(2600);
    click('.emoji-picker a.diversity-scale.medium-dark');
  });

  click("button.emoji.btn");

  click("button.emoji.btn");
  andThen(() => {
    assert.equal(
      find('.emoji-picker .list').scrollTop() > 2500,
      true,
      "it stores scroll position"
    );

    assert.equal(
      find('.emoji-picker .diversity-scale.medium-dark').hasClass('selected'),
      true,
      "it stores diversity scale"
    );
  });
});
