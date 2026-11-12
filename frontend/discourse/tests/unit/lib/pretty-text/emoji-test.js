import { setupTest } from "ember-qunit";
import {
  buildAnimatedEmojiUrl,
  buildEmojiUrl,
  emojiExists,
  isCustomEmoji,
  isSkinTonableEmoji,
  normalizeEmoji,
  performEmojiEscape,
  performEmojiUnescape,
  registerEmoji,
} from "pretty-text/emoji";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";

const OPTS = { getURL: (url) => url, emojiSet: "twitter" };

module("Unit | Pretty Text | Emoji", function (hooks) {
  setupTest(hooks);

  test("isSkinTonableEmoji", async function (assert) {
    assert.false(isSkinTonableEmoji(":smile:"));
    assert.false(isSkinTonableEmoji("smile"));
    assert.false(isSkinTonableEmoji("smile:t1"));
    assert.true(isSkinTonableEmoji(":woman_artist:"));
    assert.false(isSkinTonableEmoji(":woman_artist:t1:"));
  });

  test("buildEmojiUrl builds a standard emoji's url", function (assert) {
    assert.strictEqual(
      buildEmojiUrl("heart", OPTS),
      `/images/emoji/twitter/heart.png?v=${v}`
    );
    assert.strictEqual(
      buildEmojiUrl("HEART", OPTS),
      `/images/emoji/twitter/heart.png?v=${v}`,
      "lowercases the code"
    );
    assert.strictEqual(
      buildEmojiUrl("+1:t3", OPTS),
      `/images/emoji/twitter/+1/3.png?v=${v}`,
      "puts the skin tone in the path"
    );
    assert.strictEqual(
      buildEmojiUrl("thumbsup", OPTS),
      `/images/emoji/twitter/thumbsup.png?v=${v}`,
      "accepts an alias"
    );
    assert.strictEqual(
      buildEmojiUrl("heart", { ...OPTS, emojiCDNUrl: "https://cdn.test/e" }),
      `https://cdn.test/e/twitter/heart.png?v=${v}`,
      "uses the CDN url when set"
    );
  });

  test("buildEmojiUrl returns nothing it can't build", function (assert) {
    assert.strictEqual(buildEmojiUrl("not_an_emoji", OPTS), undefined);
    assert.strictEqual(
      buildEmojiUrl("heart", { getURL: OPTS.getURL }),
      undefined,
      "needs an emoji set"
    );
    assert.strictEqual(
      buildEmojiUrl("heart", { emojiSet: "twitter" }),
      undefined,
      "needs getURL"
    );
  });

  test("buildEmojiUrl prefers a custom emoji", function (assert) {
    assert.strictEqual(
      buildEmojiUrl("heart", {
        ...OPTS,
        customEmoji: { heart: { url: "/c/heart.png" } },
      }),
      `/c/heart.png?v=${v}`
    );
    assert.strictEqual(
      buildEmojiUrl("party", { ...OPTS, customEmoji: { party: "/c/p.png" } }),
      `/c/p.png?v=${v}`,
      "accepts a bare url"
    );
  });

  test("registerEmoji adds an emoji", function (assert) {
    registerEmoji("Pretty_Text_Test_Gadget", "/c/gadget.png", "test");

    assert.strictEqual(
      buildEmojiUrl("pretty_text_test_gadget", {}),
      `/c/gadget.png?v=${v}`
    );
    assert.true(emojiExists("pretty_text_test_gadget"));
    assert.strictEqual(
      normalizeEmoji("PRETTY_TEXT_TEST_GADGET"),
      "pretty_text_test_gadget"
    );
    assert.true(isCustomEmoji("pretty_text_test_gadget"));
  });

  test("buildAnimatedEmojiUrl builds a standard emoji's animated url", function (assert) {
    assert.strictEqual(
      buildAnimatedEmojiUrl("heart", OPTS),
      `/images/emoji/noto_animated/heart.avif?v=${v}`
    );
    assert.strictEqual(buildAnimatedEmojiUrl("not_an_emoji", OPTS), undefined);
    assert.strictEqual(
      buildAnimatedEmojiUrl("party", { ...OPTS, customEmoji: { party: "" } }),
      undefined,
      "custom emojis aren't animated"
    );
  });

  test("isCustomEmoji checks the custom emojis", function (assert) {
    assert.true(isCustomEmoji("Party", { customEmoji: { party: "/p.png" } }));
    assert.strictEqual(isCustomEmoji("heart", OPTS), undefined);
    assert.strictEqual(
      isCustomEmoji("heart"),
      undefined,
      "works without options"
    );
  });

  test("emojiExists and normalizeEmoji resolve aliases", function (assert) {
    assert.true(emojiExists("heart"));
    assert.true(emojiExists("THUMBSUP"));
    assert.false(emojiExists("not_an_emoji"));

    assert.strictEqual(normalizeEmoji("heart"), "heart");
    assert.strictEqual(normalizeEmoji("thumbsup"), "+1");
    assert.strictEqual(normalizeEmoji("not_an_emoji"), undefined);
  });

  test("performEmojiEscape turns emojis into codes", function (assert) {
    assert.strictEqual(performEmojiEscape("I ❤ it", {}), "I :heart: it");
    assert.strictEqual(
      performEmojiEscape("hi :)", { emojiShortcuts: true }),
      "hi :slight_smile:"
    );
    assert.strictEqual(
      performEmojiEscape("hi :)", {}),
      "hi :)",
      "keeps shortcuts when they're off"
    );
    assert.strictEqual(
      performEmojiEscape("hi :gadget:", {
        emojiShortcuts: true,
        customEmojiTranslation: { ":gadget:": "party" },
      }),
      "hi :party:",
      "uses the custom translations"
    );
  });

  test("performEmojiUnescape renders emoji codes as images", function (assert) {
    const url = `/images/emoji/twitter/heart.png?v=${v}`;

    assert.strictEqual(performEmojiUnescape("", OPTS), undefined);
    assert.strictEqual(
      performEmojiUnescape("a :heart: b", OPTS),
      `a <img width="20" height="20" src='${url}' title='heart' alt='heart' class='emoji'> b`
    );
    assert.strictEqual(
      performEmojiUnescape(":heart:", {
        ...OPTS,
        class: "big",
        title: "Love",
        alt: "Heart",
        tabIndex: 0,
        lazy: true,
      }),
      `<img width="20" height="20" src='${url}' title='Love' loading='lazy' alt='Heart' class='emoji big'>`
    );
    assert.strictEqual(
      performEmojiUnescape(":heart:", {
        ...OPTS,
        tabIndex: 2,
        skipTitle: true,
      }),
      `<img width="20" height="20" src='${url}'  alt='heart' class='emoji' tabindex='2'>`
    );
  });

  test("performEmojiUnescape follows the options", function (assert) {
    assert.strictEqual(
      performEmojiUnescape("a :heart: b", {
        ...OPTS,
        emojiDenyList: ["heart"],
      }),
      "a  b",
      "drops denied emojis"
    );
    assert.true(
      performEmojiUnescape("hi :)", {
        ...OPTS,
        enableEmojiShortcuts: true,
      }).includes("title='slight_smile'"),
      "renders shortcuts when they're on"
    );
    assert.strictEqual(performEmojiUnescape("hi :)", OPTS), "hi :)");
    assert.strictEqual(
      performEmojiUnescape("a:heart:", OPTS),
      "a:heart:",
      "needs a boundary before the code"
    );
    assert.true(
      performEmojiUnescape("a:heart:", { ...OPTS, inlineEmoji: true }).includes(
        "<img"
      ),
      "renders codes inside words when inline"
    );
    assert.true(
      performEmojiUnescape(":party:", {
        ...OPTS,
        customEmoji: { party: "/c/p.png" },
      }).includes("class='emoji emoji-custom'"),
      "marks custom emojis"
    );
  });
});
