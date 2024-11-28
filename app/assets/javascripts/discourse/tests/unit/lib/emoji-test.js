import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { emojiSearch } from "pretty-text/emoji";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";
import { emojiUnescape } from "discourse/lib/text";

module("Unit | Utility | emoji", function (hooks) {
  setupTest(hooks);

  test("emojiUnescape", function (assert) {
    const siteSettings = getOwner(this).lookup("service:site-settings");

    const testUnescape = (input, expected, description, settings = {}) => {
      const originalSettings = {};
      for (const [key, value] of Object.entries(settings)) {
        originalSettings[key] = siteSettings[key];
        siteSettings[key] = value;
      }

      assert.strictEqual(emojiUnescape(input), expected, description);

      for (const [key, value] of Object.entries(originalSettings)) {
        siteSettings[key] = value;
      }
    };

    testUnescape(
      "Not emoji :O) :frog) :smile)",
      "Not emoji :O) :frog) :smile)",
      "title without emoji"
    );
    testUnescape(
      "Not emoji :frog :smile",
      "Not emoji :frog :smile",
      "end colon is not optional"
    );
    testUnescape(
      "emoticons :)",
      `emoticons <img width=\"20\" height=\"20\" src='/images/emoji/twitter/slight_smile.png?v=${v}' title='slight_smile' alt='slight_smile' class='emoji'>`,
      "emoticons are still supported"
    );
    testUnescape(
      "With emoji :O: :frog: :smile:",
      `With emoji <img width=\"20\" height=\"20\" src='/images/emoji/twitter/o.png?v=${v}' title='O' alt='O' class='emoji'> <img width=\"20\" height=\"20\" src='/images/emoji/twitter/frog.png?v=${v}' title='frog' alt='frog' class='emoji'> <img width=\"20\" height=\"20\" src='/images/emoji/twitter/smile.png?v=${v}' title='smile' alt='smile' class='emoji'>`,
      "title with emoji"
    );
    testUnescape(
      "a:smile:a",
      "a:smile:a",
      "word characters not allowed next to emoji"
    );
    testUnescape(
      "(:frog:) :)",
      `(<img width=\"20\" height=\"20\" src='/images/emoji/twitter/frog.png?v=${v}' title='frog' alt='frog' class='emoji'>) <img width=\"20\" height=\"20\" src='/images/emoji/twitter/slight_smile.png?v=${v}' title='slight_smile' alt='slight_smile' class='emoji'>`,
      "non-word characters allowed next to emoji"
    );
    testUnescape(
      ":smile: hi",
      `<img width=\"20\" height=\"20\" src='/images/emoji/twitter/smile.png?v=${v}' title='smile' alt='smile' class='emoji'> hi`,
      "start of line"
    );
    testUnescape(
      "hi :smile:",
      `hi <img width=\"20\" height=\"20\" src='/images/emoji/twitter/smile.png?v=${v}' title='smile' alt='smile' class='emoji'>`,
      "end of line"
    );
    testUnescape(
      "hi :blonde_woman:t4:",
      `hi <img width=\"20\" height=\"20\" src='/images/emoji/twitter/blonde_woman/4.png?v=${v}' title='blonde_woman:t4' alt='blonde_woman:t4' class='emoji'>`,
      "support for skin tones"
    );
    testUnescape(
      "hi :blonde_woman:t4: :blonde_man:t6:",
      `hi <img width=\"20\" height=\"20\" src='/images/emoji/twitter/blonde_woman/4.png?v=${v}' title='blonde_woman:t4' alt='blonde_woman:t4' class='emoji'> <img width=\"20\" height=\"20\" src='/images/emoji/twitter/blonde_man/6.png?v=${v}' title='blonde_man:t6' alt='blonde_man:t6' class='emoji'>`,
      "support for multiple skin tones"
    );
    testUnescape(
      "hi :blonde_man:t6",
      "hi :blonde_man:t6",
      "end colon not optional for skin tones"
    );
    testUnescape(
      "emoticons :)",
      "emoticons :)",
      "no emoticons when emojis are disabled",
      { enable_emoji: false }
    );
    testUnescape(
      "emoji :smile:",
      "emoji :smile:",
      "no emojis when emojis are disabled",
      { enable_emoji: false }
    );
    testUnescape(
      "emoticons :)",
      "emoticons :)",
      "no emoticons when emoji shortcuts are disabled",
      { enable_emoji_shortcuts: false }
    );
    testUnescape(
      "Hello 😊 World",
      `Hello <img width=\"20\" height=\"20\" src='/images/emoji/twitter/blush.png?v=${v}' title='blush' alt='blush' class='emoji'> World`,
      "emoji from Unicode emoji"
    );
    testUnescape(
      "Hello😊World",
      "Hello😊World",
      "keeps Unicode emoji when inline translation disabled",
      {
        enable_inline_emoji_translation: false,
      }
    );
    testUnescape(
      "Hello😊World",
      `Hello<img width=\"20\" height=\"20\" src='/images/emoji/twitter/blush.png?v=${v}' title='blush' alt='blush' class='emoji'>World`,
      "emoji from Unicode emoji when inline translation enabled",
      {
        enable_inline_emoji_translation: true,
      }
    );
    testUnescape(
      "hi:smile:",
      "hi:smile:",
      "no emojis when inline translation disabled",
      {
        enable_inline_emoji_translation: false,
      }
    );
    testUnescape(
      "hi:smile:",
      `hi<img width=\"20\" height=\"20\" src='/images/emoji/twitter/smile.png?v=${v}' title='smile' alt='smile' class='emoji'>`,
      "emoji when inline translation enabled",
      { enable_inline_emoji_translation: true }
    );
    assert.strictEqual(
      emojiUnescape(":smile:", { tabIndex: "0" }),
      `<img width=\"20\" height=\"20\" src='/images/emoji/twitter/smile.png?v=${v}' title='smile' alt='smile' class='emoji' tabindex='0'>`,
      "emoji when tabindex is enabled"
    );
  });

  test("Emoji search", function (assert) {
    // able to find an alias
    assert.strictEqual(emojiSearch("+1").length, 1);

    // able to find middle of line search
    assert.strictEqual(emojiSearch("check", { maxResults: 3 }).length, 3);

    // appends diversity
    assert.deepEqual(emojiSearch("woman_artist", { diversity: 5 }), [
      "woman_artist:t5",
    ]);
    assert.deepEqual(emojiSearch("woman_artist", { diversity: 2 }), [
      "woman_artist:t2",
    ]);

    // no diversity appended for emojis that can't be diversified
    assert.deepEqual(emojiSearch("green_apple", { diversity: 3 }), [
      "green_apple",
    ]);
  });

  test("search does not return duplicated results", function (assert) {
    const matches = emojiSearch("bow").filter(
      (emoji) => emoji === "bowing_man"
    );

    assert.deepEqual(matches, ["bowing_man"]);
  });

  test("search does partial-match on emoji aliases", function (assert) {
    const matches = emojiSearch("instru");

    assert.true(matches.includes("woman_teacher"));
    assert.true(matches.includes("violin"));
  });
});
