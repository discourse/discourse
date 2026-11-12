import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import { module, test } from "qunit";
import { getURLWithCDN } from "discourse/lib/get-url";
import {
  animatedEmojiUrlFor,
  buildBBCodeAttrs,
  cook,
  emojiOptions,
  emojiUrlFor,
  excerpt,
  generateCookFunction,
  generateLinkifyFunction,
  humanizeList,
  parseAsync,
  parseBBCodeTag,
  parseMentions,
  sanitize,
  sanitizeAsync,
  serializeBBCodeAttr,
} from "discourse/lib/text";
import { QUOTATION_MARKS } from "discourse-markdown-it/features/bbcode-block";

module("Unit | Utility | text", function (hooks) {
  setupTest(hooks);

  test("parseAsync", async function (assert) {
    await parseAsync("**test**").then((tokens) => {
      assert.strictEqual(
        tokens[1].children[1].type,
        "strong_open",
        "it parses the raw markdown"
      );
    });
  });

  test("excerpt", async function (assert) {
    let cooked = await cook("Hello! :wave:");
    assert.strictEqual(
      await excerpt(cooked, 300),
      `Hello! <img src="/images/emoji/twitter/wave.png?v=${v}" title=":wave:" class="emoji" alt=":wave:" loading="lazy" width="20" height="20">`
    );

    cooked = await cook("[:wave:](https://example.com)");
    assert.strictEqual(
      await excerpt(cooked, 300),
      `<a href="https://example.com"><img src="/images/emoji/twitter/wave.png?v=${v}" title=":wave:" class="emoji only-emoji" alt=":wave:" loading="lazy" width="20" height="20"></a>`
    );

    cooked = await cook('<script>alert("hi")</script>');
    assert.strictEqual(await excerpt(cooked, 300), "");

    cooked = await cook("[`<script>alert('hi')</script>`]()");
    assert.strictEqual(
      await excerpt(cooked, 300),
      "<a><code>&lt;script&gt;alert('hi')&lt;/script&gt;</code></a>"
    );
  });
});

module("Unit | Utility | text | parseMentions", function (hooks) {
  setupTest(hooks);

  test("parses mentions from markdown", async function (assert) {
    const markdown = "Hey @user1, @user2, @group1, @group2, @here, @all";
    const mentions = await parseMentions(markdown);
    assert.deepEqual(mentions, [
      "user1",
      "user2",
      "group1",
      "group2",
      "here",
      "all",
    ]);
  });

  test("ignores duplicated mentions", async function (assert) {
    const markdown = "Hey @john, @john, @john, @john";
    const mentions = await parseMentions(markdown);
    assert.deepEqual(mentions, ["john"]);
  });

  test("ignores mentions in codeblocks", async function (assert) {
    const markdown = `Hey
    \`\`\`
      def foo
        @bar = true
      end
    \`\`\`
    `;
    const mentions = await parseMentions(markdown);
    assert.strictEqual(mentions.length, 0);
  });
});

module("Unit | Utility | text | serializeBBCodeAttr", function () {
  test("returns empty string for falsy values", function (assert) {
    assert.strictEqual(serializeBBCodeAttr(null, "name"), "");
    assert.strictEqual(serializeBBCodeAttr(undefined, "name"), "");
    assert.strictEqual(serializeBBCodeAttr("", "name"), "");
  });

  test("serializes simple values without quotes", function (assert) {
    assert.strictEqual(serializeBBCodeAttr("value", "name"), " name=value");
    assert.strictEqual(
      serializeBBCodeAttr("12:00:00", "time"),
      " time=12:00:00"
    );
  });

  test("serializes values with whitespace using double quotes", function (assert) {
    assert.strictEqual(
      serializeBBCodeAttr("hello world", "name"),
      ' name="hello world"'
    );
  });

  test("serializes values with ] using quotes", function (assert) {
    assert.strictEqual(
      serializeBBCodeAttr("value]test", "name"),
      ' name="value]test"'
    );
  });

  test("uses single quotes when value contains double quotes", function (assert) {
    assert.strictEqual(
      serializeBBCodeAttr('Design "Gems" Discussion', "channel"),
      " channel='Design \"Gems\" Discussion'"
    );
  });

  test("uses double quotes when value contains single quotes", function (assert) {
    assert.strictEqual(
      serializeBBCodeAttr("it's great", "title"),
      ' title="it\'s great"'
    );
  });

  test("uses guillemets when both ASCII quote types present", function (assert) {
    assert.strictEqual(
      serializeBBCodeAttr(`Sam's "Release" discussion`, "title"),
      ` title=«Sam's "Release" discussion»`
    );
  });

  test("uses non-conflicting delimiter and preserves value", function (assert) {
    QUOTATION_MARKS.forEach((pair, index) => {
      const [open, close] = pair;

      // Create a value containing all delimiter characters except the one being tested
      let conflictingChars = Array.from(QUOTATION_MARKS);
      conflictingChars = conflictingChars.filter(
        (p) => !p.includes(open) && !p.includes(close)
      );
      conflictingChars = conflictingChars.join("");
      const value = `test ${conflictingChars} value`;
      const result = serializeBBCodeAttr(value, "attr");

      // Find which delimiter was used
      const usedPair = QUOTATION_MARKS.find(
        ([o, c]) => result.startsWith(` attr=${o}`) && result.endsWith(c)
      );

      // Assert a non-conflicting delimiter was used
      const hasConflict =
        usedPair &&
        !value.includes(usedPair[0]) &&
        !value.includes(usedPair[1]);

      assert.true(
        hasConflict,
        `delimiter ${index} (${open}${close}): a non-conflicting delimiter is used`
      );

      // Assert the value is preserved
      assert.true(
        result.includes(value),
        `delimiter ${index} (${open}${close}): value is preserved`
      );
    });
  });
});

module("Unit | Utility | text | buildBBCodeAttrs", function () {
  test("builds attributes string from object", function (assert) {
    const attrs = { foo: "bar", baz: "qux" };
    assert.strictEqual(buildBBCodeAttrs(attrs), "foo=bar baz=qux");
  });

  test("skips null and undefined values", function (assert) {
    const attrs = { foo: "bar", skip: null, also: undefined, baz: "qux" };
    assert.strictEqual(buildBBCodeAttrs(attrs), "foo=bar baz=qux");
  });

  test("skips specified attributes", function (assert) {
    const attrs = { foo: "bar", skip: "this", baz: "qux" };
    assert.strictEqual(
      buildBBCodeAttrs(attrs, { skipAttrs: ["skip"] }),
      "foo=bar baz=qux"
    );
  });

  test("quotes values with whitespace", function (assert) {
    const attrs = { name: "hello world" };
    assert.strictEqual(buildBBCodeAttrs(attrs), 'name="hello world"');
  });

  test("switches to single quotes for values with double quotes", function (assert) {
    const attrs = { channel: 'Design "Gems" :tada:' };
    assert.strictEqual(
      buildBBCodeAttrs(attrs),
      "channel='Design \"Gems\" :tada:'"
    );
  });
});

module("Unit | Utility | text | engine", function (hooks) {
  setupTest(hooks);

  test("generateCookFunction returns a function that cooks", async function (assert) {
    const cookFn = await generateCookFunction({});

    assert.strictEqual(cookFn("**gadget**"), "<p><strong>gadget</strong></p>");
  });

  test("generateLinkifyFunction returns a link matcher", async function (assert) {
    const linkify = await generateLinkifyFunction({});

    assert.true(linkify.test("see https://example.com"));
    assert.false(linkify.test("no links here"));
  });

  test("sanitize removes what the allow list doesn't allow", function (assert) {
    assert.strictEqual(
      sanitize("<b>gadget</b><script>alert(1)</script>"),
      "<b>gadget</b>"
    );
  });

  test("sanitizeAsync removes what the allow list doesn't allow", async function (assert) {
    assert.strictEqual(
      await sanitizeAsync("<b>gadget</b><script>alert(1)</script>"),
      "<b>gadget</b>"
    );
  });

  test("parseBBCodeTag parses a closing tag", function (assert) {
    assert.deepEqual(parseBBCodeTag("[/quote]", 0, 8), {
      tag: "quote",
      closing: true,
      length: 8,
    });
  });
});

module("Unit | Utility | text | emoji", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = getOwner(this).lookup("service:site-settings");
    this.originalEnableEmoji = this.siteSettings.enable_emoji;
  });

  hooks.afterEach(function () {
    this.siteSettings.enable_emoji = this.originalEnableEmoji;
  });

  test("emojiOptions reads the emoji settings", function (assert) {
    this.siteSettings.enable_emoji = true;
    const options = emojiOptions();

    assert.strictEqual(options.emojiSet, this.siteSettings.emoji_set);
    assert.strictEqual(
      options.enableEmojiShortcuts,
      this.siteSettings.enable_emoji_shortcuts
    );
    assert.strictEqual(
      options.inlineEmoji,
      this.siteSettings.enable_inline_emoji_translation
    );
    assert.strictEqual(
      options.emojiCDNUrl,
      this.siteSettings.external_emoji_url
    );
    assert.strictEqual(
      options.getURL("/gadget.png"),
      getURLWithCDN("/gadget.png")
    );
  });

  test("emojiOptions returns nothing while emoji are disabled", function (assert) {
    this.siteSettings.enable_emoji = false;

    assert.strictEqual(emojiOptions(), undefined);
  });

  test("emojiUrlFor builds the emoji URL", function (assert) {
    this.siteSettings.enable_emoji = true;
    assert.strictEqual(
      emojiUrlFor("smile"),
      `/images/emoji/${this.siteSettings.emoji_set}/smile.png?v=${v}`
    );

    this.siteSettings.enable_emoji = false;
    assert.strictEqual(emojiUrlFor("smile"), undefined);
  });

  test("animatedEmojiUrlFor builds the animated emoji URL", function (assert) {
    this.siteSettings.enable_emoji = true;
    assert.strictEqual(
      animatedEmojiUrlFor("smile"),
      `/images/emoji/noto_animated/smile.avif?v=${v}`
    );

    this.siteSettings.enable_emoji = false;
    assert.strictEqual(animatedEmojiUrlFor("smile"), undefined);
  });
});

module("Unit | Utility | text | humanizeList", function () {
  test("joins the items with the last one after 'and'", function (assert) {
    assert.strictEqual(humanizeList(["a", "b", "c"]), "a, b and c");
    assert.strictEqual(humanizeList(new Set(["a", "b"])), "a and b");
  });

  test("returns a single item as is", function (assert) {
    assert.strictEqual(humanizeList(["a"]), "a");
  });
});
