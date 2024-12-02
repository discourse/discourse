import { setupTest } from "ember-qunit";
import { registerEmoji } from "pretty-text/emoji";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";
import {
  applyCachedInlineOnebox,
  deleteCachedInlineOnebox,
} from "pretty-text/inline-oneboxer";
import QUnit, { module, test } from "qunit";
import { deepMerge } from "discourse-common/lib/object";
import DiscourseMarkdownIt from "discourse-markdown-it";
import { extractDataAttribute } from "discourse-markdown-it/engine";

const rawOpts = {
  siteSettings: {
    enable_emoji: true,
    enable_emoji_shortcuts: true,
    enable_mentions: true,
    emoji_set: "twitter",
    external_emoji_url: "",
    highlighted_languages: "json|ruby|javascript|xml",
    default_code_lang: "auto",
    enable_markdown_linkify: true,
    markdown_linkify_tlds: "com",
    display_name_on_posts: false,
    prioritize_username_in_ux: true,
  },
  getURL: (url) => url,
};

function build(options = rawOpts) {
  return DiscourseMarkdownIt.withDefaultFeatures().withOptions(options);
}

QUnit.assert.cooked = function (input, expected, message) {
  const actual = build().cook(input);
  this.pushResult({
    result: actual === expected.replace(/\/>/g, ">"),
    actual,
    expected,
    message,
  });
};

QUnit.assert.cookedOptions = function (input, opts, expected, message) {
  const merged = deepMerge({}, rawOpts, opts);
  const actual = build(merged).cook(input);
  this.pushResult({
    result: actual === expected,
    actual,
    expected,
    message,
  });
};

QUnit.assert.cookedPara = function (input, expected, message) {
  QUnit.assert.cooked(input, `<p>${expected}</p>`, message);
};

module("Unit | Utility | pretty-text", function (hooks) {
  setupTest(hooks);

  test("buildOptions", function (assert) {
    assert.true(
      build({ siteSettings: { enable_emoji: true } }).options.discourse.features
        .emoji,
      "emoji enabled"
    );
    assert.false(
      build({ siteSettings: { enable_emoji: false } }).options.discourse
        .features.emoji,
      "emoji disabled"
    );
    assert.deepEqual(
      build({ siteSettings: { allowed_iframes: "https://example.com/" } })
        .options.discourse.allowedIframes,
      ["https://example.com/"],
      "doesn't filter out valid urls"
    );
    assert.deepEqual(
      build({ siteSettings: { allowed_iframes: "https://example.com" } })
        .options.discourse.allowedIframes,
      [],
      "filters out invalid urls. Requires 3 slashes"
    );
  });

  test("basic cooking", function (assert) {
    assert.cooked("hello", "<p>hello</p>", "surrounds text with paragraphs");
    assert.cooked("**evil**", "<p><strong>evil</strong></p>", "bolds text");
    assert.cooked("__bold__", "<p><strong>bold</strong></p>", "bolds text");
    assert.cooked("*trout*", "<p><em>trout</em></p>", "italicizes text");
    assert.cooked("_trout_", "<p><em>trout</em></p>", "italicizes text");
    assert.cooked(
      "***hello***",
      "<p><em><strong>hello</strong></em></p>",
      "can do bold and italics at once"
    );
    assert.cooked(
      "word_with_underscores",
      "<p>word_with_underscores</p>",
      "doesn't do intraword italics"
    );
    assert.cooked(
      "common/_special_font_face.html.erb",
      "<p>common/_special_font_face.html.erb</p>",
      "doesn't intraword with a slash"
    );
    assert.cooked(
      "hello \\*evil\\*",
      "<p>hello *evil*</p>",
      "supports escaping of asterisks"
    );
    assert.cooked(
      "hello \\_evil\\_",
      "<p>hello _evil_</p>",
      "supports escaping of italics"
    );
    assert.cooked(
      "brussels sprouts are *awful*.",
      "<p>brussels sprouts are <em>awful</em>.</p>",
      "doesn't swallow periods"
    );
  });

  test("Nested bold and italics", function (assert) {
    assert.cooked(
      "*this is italic **with some bold** inside*",
      "<p><em>this is italic <strong>with some bold</strong> inside</em></p>",
      "handles nested bold in italics"
    );
  });

  test("Traditional Line Breaks", function (assert) {
    const input = "1\n2\n3";
    assert.cooked(
      input,
      "<p>1<br>\n2<br>\n3</p>",
      "automatically handles trivial newlines"
    );
    assert.cookedOptions(
      input,
      { siteSettings: { traditional_markdown_linebreaks: true } },
      "<p>1\n2\n3</p>"
    );
  });

  test("Unbalanced underscores", function (assert) {
    assert.cooked(
      "[evil_trout][1] hello_\n\n[1]: http://eviltrout.com",
      '<p><a href="http://eviltrout.com">evil_trout</a> hello_</p>'
    );
  });

  test("Line Breaks", function (assert) {
    assert.cooked(
      "[] first choice\n[] second choice",
      "<p>[] first choice<br>\n[] second choice</p>",
      "handles new lines correctly with [] options"
    );

    // note this is a change from previous engine but is correct
    // we have an html block and behavior is defined per common mark
    // spec
    // ole engine would wrap trout in a <p>
    assert.cooked(
      "<blockquote>evil</blockquote>\ntrout",
      "<blockquote>evil</blockquote>\ntrout",
      "doesn't insert <br> after blockquotes"
    );

    assert.cooked(
      "leading<blockquote>evil</blockquote>\ntrout",
      "<p>leading<blockquote>evil</blockquote><br>\ntrout</p>",
      "doesn't insert <br> after blockquotes with leading text"
    );
  });

  test("Paragraphs for HTML", function (assert) {
    assert.cooked(
      "<div>hello world</div>",
      "<div>hello world</div>",
      "doesn't surround <div> with paragraphs"
    );
    assert.cooked(
      "<p>hello world</p>",
      "<p>hello world</p>",
      "doesn't surround <p> with paragraphs"
    );
    assert.cooked(
      "<i>hello world</i>",
      "<p><i>hello world</i></p>",
      "surrounds inline <i> html tags with paragraphs"
    );
    assert.cooked(
      "<b>hello world</b>",
      "<p><b>hello world</b></p>",
      "surrounds inline <b> html tags with paragraphs"
    );
  });

  test("Links", function (assert) {
    assert.cooked(
      "EvilTrout: http://eviltrout.com",
      '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a></p>',
      "autolinks a URL"
    );

    const link = "http://www.youtube.com/watch?v=1MrpeBRkM5A";

    assert.cooked(
      `Youtube: ${link}`,
      `<p>Youtube: <a href="${link}" class="inline-onebox-loading">${link}</a></p>`,
      "allows links to contain query params"
    );

    try {
      applyCachedInlineOnebox(link, {});

      assert.cooked(
        `Youtube: ${link}`,
        `<p>Youtube: <a href="${link}">${link}</a></p>`
      );
    } finally {
      deleteCachedInlineOnebox(link);
    }

    assert.cooked(
      "Derpy: http://derp.com?__test=1",
      `<p>Derpy: <a href="http://derp.com?__test=1" class="inline-onebox-loading">http://derp.com?__test=1</a></p>`,
      "works with double underscores in urls"
    );

    assert.cooked(
      "Atwood: www.codinghorror.com",
      '<p>Atwood: <a href="http://www.codinghorror.com">www.codinghorror.com</a></p>',
      "autolinks something that begins with www"
    );

    assert.cooked(
      "Atwood: http://www.codinghorror.com",
      '<p>Atwood: <a href="http://www.codinghorror.com">http://www.codinghorror.com</a></p>',
      "autolinks a URL with http://www"
    );

    assert.cooked(
      "EvilTrout: http://eviltrout.com hello",
      '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a> hello</p>',
      "autolinks with trailing text"
    );

    assert.cooked(
      "here is [an example](http://twitter.com)",
      '<p>here is <a href="http://twitter.com">an example</a></p>',
      "supports markdown style links"
    );

    assert.cooked(
      "Batman: http://en.wikipedia.org/wiki/The_Dark_Knight_(film)",
      `<p>Batman: <a href="http://en.wikipedia.org/wiki/The_Dark_Knight_(film)" class="inline-onebox-loading">http://en.wikipedia.org/wiki/The_Dark_Knight_(film)</a></p>`,
      "autolinks a URL with parentheses (like Wikipedia)"
    );

    assert.cooked(
      "Here's a tweet:\nhttps://twitter.com/evil_trout/status/345954894420787200",
      '<p>Here\'s a tweet:<br>\n<a href="https://twitter.com/evil_trout/status/345954894420787200" class="onebox" target="_blank">https://twitter.com/evil_trout/status/345954894420787200</a></p>',
      "doesn't strip the new line"
    );

    assert.cooked(
      "1. View @eviltrout's profile here: http://meta.discourse.org/u/eviltrout/activity<br/>next line.",
      `<ol>\n<li>View <span class="mention">@eviltrout</span>\'s profile here: <a href="http://meta.discourse.org/u/eviltrout/activity" class="inline-onebox-loading">http://meta.discourse.org/u/eviltrout/activity</a><br>next line.</li>\n</ol>`,
      "allows autolinking within a list without inserting a paragraph"
    );

    assert.cooked(
      "[3]: http://eviltrout.com",
      "",
      "doesn't autolink markdown link references"
    );

    assert.cooked(
      "[]: http://eviltrout.com",
      '<p>[]: <a href="http://eviltrout.com">http://eviltrout.com</a></p>',
      "doesn't accept empty link references"
    );

    assert.cooked(
      "[b]label[/b]: description",
      '<p><span class="bbcode-b">label</span>: description</p>',
      "doesn't accept BBCode as link references"
    );

    assert.cooked(
      "http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369",
      '<p><a href="http://discourse.org">http://discourse.org</a> and ' +
        `<a href="http://discourse.org/another_url" class="inline-onebox-loading">http://discourse.org/another_url</a> and ` +
        `<a href="http://www.imdb.com/name/nm2225369" class="inline-onebox-loading">http://www.imdb.com/name/nm2225369</a></p>`,
      "allows multiple links on one line"
    );

    assert.cooked(
      "* [Evil Trout][1]\n\n[1]: http://eviltrout.com",
      '<ul>\n<li><a href="http://eviltrout.com">Evil Trout</a></li>\n</ul>',
      "allows markdown link references in a list"
    );

    assert.cooked(
      "User [MOD]: Hello!",
      "<p>User [MOD]: Hello!</p>",
      "does not consider references that are obviously not URLs"
    );

    assert.cooked(
      "<small>http://eviltrout.com</small>",
      '<p><small><a href="http://eviltrout.com">http://eviltrout.com</a></small></p>',
      "Links within HTML tags"
    );

    assert.cooked(
      "[http://google.com ... wat](http://discourse.org)",
      '<p><a href="http://discourse.org">http://google.com ... wat</a></p>',
      "supports links within links"
    );

    assert.cooked(
      "[http://google.com](http://discourse.org)",
      '<p><a href="http://discourse.org">http://google.com</a></p>',
      "supports markdown links where the name and link match"
    );

    assert.cooked(
      '[Link](http://www.example.com) (with an outer "description")',
      '<p><a href="http://www.example.com">Link</a> (with an outer &quot;description&quot;)</p>',
      "doesn't consume closing parens as part of the url"
    );

    assert.cooked(
      "A link inside parentheses (http://www.example.com)",
      '<p>A link inside parentheses (<a href="http://www.example.com">http://www.example.com</a>)</p>',
      "auto-links a url within parentheses"
    );

    assert.cooked(
      "[ul][1]\n\n[1]: http://eviltrout.com",
      '<p><a href="http://eviltrout.com">ul</a></p>',
      "can use `ul` as a link name"
    );
  });

  test("simple quotes", function (assert) {
    assert.cooked(
      "> nice!",
      "<blockquote>\n<p>nice!</p>\n</blockquote>",
      "supports simple quotes"
    );
    assert.cooked(
      " > nice!",
      "<blockquote>\n<p>nice!</p>\n</blockquote>",
      "allows quotes with preceding spaces"
    );
    assert.cooked(
      "> level 1\n> > level 2",
      "<blockquote>\n<p>level 1</p>\n<blockquote>\n<p>level 2</p>\n</blockquote>\n</blockquote>",
      "allows nesting of blockquotes"
    );
    assert.cooked(
      "> level 1\n>  > level 2",
      "<blockquote>\n<p>level 1</p>\n<blockquote>\n<p>level 2</p>\n</blockquote>\n</blockquote>",
      "allows nesting of blockquotes with spaces"
    );

    assert.cooked(
      "- hello\n\n  > world\n  > eviltrout",
      `<ul>
<li>
<p>hello</p>
<blockquote>
<p>world<br>
eviltrout</p>
</blockquote>
</li>
</ul>`,
      "allows quotes within a list"
    );

    assert.cooked(
      "- <p>eviltrout</p>",
      "<ul>\n<li>\n<p>eviltrout</p></li>\n</ul>",
      "allows paragraphs within a list"
    );

    assert.cooked(
      "  > indent 1\n  > indent 2",
      "<blockquote>\n<p>indent 1<br>\nindent 2</p>\n</blockquote>",
      "allow multiple spaces to indent"
    );
  });

  test("Quotes", function (assert) {
    assert.cookedOptions(
      '[quote="eviltrout, post: 1"]\na quote\n\nsecond line\n\nthird line\n[/quote]',
      { topicId: 2 },
      `<aside class=\"quote no-group\" data-username=\"eviltrout\" data-post=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 eviltrout:</div>
<blockquote>
<p>a quote</p>
<p>second line</p>
<p>third line</p>
</blockquote>
</aside>`,
      "works with multiple lines"
    );

    assert.cookedOptions(
      '[quote="bob, post:1"]\nmy quote\n[/quote]',
      { topicId: 2, lookupAvatar: function () {} },
      `<aside class=\"quote no-group\" data-username=\"bob\" data-post=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 bob:</div>
<blockquote>
<p>my quote</p>
</blockquote>
</aside>`,
      "includes no avatar if none is found"
    );

    assert.cooked(
      `[quote]\na\n\n[quote]\nb\n[/quote]\n[/quote]`,
      `<aside class=\"quote no-group\">
<blockquote>
<p>a</p>
<aside class=\"quote no-group\">
<blockquote>
<p>b</p>
</blockquote>
</aside>
</blockquote>
</aside>`,
      "handles nested quotes properly"
    );

    assert.cookedOptions(
      `[quote="bob, post:1, topic:1"]\ntest quote\n[/quote]`,
      { lookupPrimaryUserGroupByPostNumber: () => "aUserGroup" },
      `<aside class="quote group-aUserGroup" data-username="bob" data-post="1" data-topic="1">
<div class="title">
<div class="quote-controls"></div>
 bob:</div>
<blockquote>
<p>test quote</p>
</blockquote>
</aside>`,
      "quote has group class"
    );

    assert.cooked(
      "[quote]\ntest\n[/quote]",
      '<aside class="quote no-group">\n<blockquote>\n<p>test</p>\n</blockquote>\n</aside>',
      "supports quotes without params"
    );

    assert.cooked(
      "[quote]\n*test*\n[/quote]",
      '<aside class="quote no-group">\n<blockquote>\n<p><em>test</em></p>\n</blockquote>\n</aside>',
      "doesn't insert a new line for italics"
    );

    assert.cooked(
      "[quote=,script='a'><script>alert('test');//':a]\n[/quote]",
      '<aside class="quote no-group">\n<blockquote></blockquote>\n</aside>',
      "will not create a script tag within an attribute"
    );
  });

  test("Incomplete quotes", function (assert) {
    assert.cookedOptions(
      '[quote=", post: 1"]\na quote\n[/quote]',
      { topicId: 2 },
      `<aside class=\"quote no-group\" data-post=\"1\">
<blockquote>
<p>a quote</p>
</blockquote>
</aside>`,
      "works with missing username"
    );
  });

  test("Mentions", function (assert) {
    assert.cooked(
      "Hello @sam",
      '<p>Hello <span class="mention">@sam</span></p>',
      "translates mentions to links"
    );

    assert.cooked(
      "[@codinghorror](https://twitter.com/codinghorror)",
      '<p><a href="https://twitter.com/codinghorror">@codinghorror</a></p>',
      "doesn't do mentions within links"
    );

    assert.cooked(
      "[@codinghorror](https://twitter.com/codinghorror)",
      '<p><a href="https://twitter.com/codinghorror">@codinghorror</a></p>',
      "doesn't do link mentions within links"
    );

    assert.cooked(
      "Hello @EvilTrout",
      '<p>Hello <span class="mention">@EvilTrout</span></p>',
      "adds a mention class"
    );

    assert.cooked(
      "robin@email.host",
      "<p>robin@email.host</p>",
      "won't add mention class to an email address"
    );

    assert.cooked(
      "hanzo55@yahoo.com",
      '<p><a href="mailto:hanzo55@yahoo.com">hanzo55@yahoo.com</a></p>',
      "won't be affected by email addresses that have a number before the @ symbol"
    );

    assert.cooked(
      "@EvilTrout yo",
      '<p><span class="mention">@EvilTrout</span> yo</p>',
      "handles mentions at the beginning of a string"
    );

    assert.cooked(
      "yo\n@EvilTrout",
      '<p>yo<br>\n<span class="mention">@EvilTrout</span></p>',
      "handles mentions at the beginning of a new line"
    );

    assert.cooked(
      "`evil` @EvilTrout `trout`",
      '<p><code>evil</code> <span class="mention">@EvilTrout</span> <code>trout</code></p>',
      "deals correctly with multiple <code> blocks"
    );

    assert.cooked(
      "```\na @test\n```",
      '<pre><code class="lang-auto">a @test\n</code></pre>',
      "should not do mentions within a code block"
    );

    assert.cooked(
      "> foo bar baz @eviltrout",
      '<blockquote>\n<p>foo bar baz <span class="mention">@eviltrout</span></p>\n</blockquote>',
      "handles mentions in simple quotes"
    );

    assert.cooked(
      "> foo bar baz @eviltrout ohmagerd\nlook at this",
      '<blockquote>\n<p>foo bar baz <span class="mention">@eviltrout</span> ohmagerd<br>\nlook at this</p>\n</blockquote>',
      "does mentions properly with trailing text within a simple quote"
    );

    assert.cooked(
      "`code` is okay before @mention",
      '<p><code>code</code> is okay before <span class="mention">@mention</span></p>',
      "Does not mention in an inline code block"
    );

    assert.cooked(
      "@mention is okay before `code`",
      '<p><span class="mention">@mention</span> is okay before <code>code</code></p>',
      "Does not mention in an inline code block"
    );

    assert.cooked(
      "don't `@mention`",
      "<p>don't <code>@mention</code></p>",
      "Does not mention in an inline code block"
    );

    assert.cooked(
      "Yes `@this` should be code @eviltrout",
      '<p>Yes <code>@this</code> should be code <span class="mention">@eviltrout</span></p>',
      "Does not mention in an inline code block"
    );

    assert.cooked(
      "@eviltrout and `@eviltrout`",
      '<p><span class="mention">@eviltrout</span> and <code>@eviltrout</code></p>',
      "you can have a mention in an inline code block following a real mention"
    );

    assert.cooked(
      "1. this is  a list\n\n2. this is an @eviltrout mention\n",
      '<ol>\n<li>\n<p>this is  a list</p>\n</li>\n<li>\n<p>this is an <span class="mention">@eviltrout</span> mention</p>\n</li>\n</ol>',
      "mentions properly in a list"
    );

    assert.cooked(
      "Hello @foo/@bar",
      '<p>Hello <span class="mention">@foo</span>/<span class="mention">@bar</span></p>',
      "handles mentions separated by a slash"
    );

    assert.cooked(
      "<small>a @sam c</small>",
      '<p><small>a <span class="mention">@sam</span> c</small></p>',
      "allows mentions within HTML tags"
    );

    assert.cooked(
      "@_sam @1sam @ab-cd.123_ABC-xYz @sam1",
      '<p><span class="mention">@_sam</span> <span class="mention">@1sam</span> <span class="mention">@ab-cd.123_ABC-xYz</span> <span class="mention">@sam1</span></p>',
      "detects mentions of valid usernames"
    );

    assert.cooked(
      "@.sam @-sam @sam. @sam_ @sam-",
      '<p>@.sam @-sam <span class="mention">@sam</span>. <span class="mention">@sam</span>_ <span class="mention">@sam</span>-</p>',
      "does not detect mentions of invalid usernames"
    );

    assert.cookedOptions(
      "Hello @狮子",
      { siteSettings: { unicode_usernames: false } },
      "<p>Hello @狮子</p>",
      "does not detect mentions of Unicode usernames"
    );
  });

  test("Mentions - Unicode usernames enabled", function (assert) {
    assert.cookedOptions(
      "Hello @狮子",
      { siteSettings: { unicode_usernames: true } },
      '<p>Hello <span class="mention">@狮子</span></p>',
      "detects mentions of Unicode usernames"
    );

    assert.cookedOptions(
      "@狮子 @_狮子 @1狮子 @狮-ø.١٢٣_Ö-ழ் @狮子1",
      { siteSettings: { unicode_usernames: true } },
      '<p><span class="mention">@狮子</span> <span class="mention">@_狮子</span> <span class="mention">@1狮子</span> <span class="mention">@狮-ø.١٢٣_Ö-ழ்</span> <span class="mention">@狮子1</span></p>',
      "detects mentions of valid Unicode usernames"
    );

    assert.cookedOptions(
      "@.狮子 @-狮子 @狮子. @狮子_ @狮子-",
      { siteSettings: { unicode_usernames: true } },
      '<p>@.狮子 @-狮子 <span class="mention">@狮子</span>. <span class="mention">@狮子</span>_ <span class="mention">@狮子</span>-</p>',
      "does not detect mentions of invalid Unicode usernames"
    );
  });

  test("Mentions - disabled", function (assert) {
    assert.cookedOptions(
      "@eviltrout",
      { siteSettings: { enable_mentions: false } },
      "<p>@eviltrout</p>"
    );
  });

  test("Heading", function (assert) {
    assert.cooked(
      "**Bold**\n----------",
      '<h2><a name="bold-1" class="anchor" href="#bold-1"></a><strong>Bold</strong></h2>',
      "will bold the heading"
    );
  });

  test("Heading anchors are valid", function (assert) {
    assert.cooked(
      "# One\n\n# 1\n\n# $$",
      '<h1><a name="one-1" class="anchor" href="#one-1"></a>One</h1>\n' +
        '<h1><a name="h-1-2" class="anchor" href="#h-1-2"></a>1</h1>\n' +
        '<h1><a name="h-3" class="anchor" href="#h-3"></a>$$</h1>',
      "will bold the heading"
    );
  });

  test("Heading anchors with post id", function (assert) {
    assert.cookedOptions(
      "# 1\n\n# one",
      { postId: 1234 },
      '<h1><a name="p-1234-h-1-1" class="anchor" href="#p-1234-h-1-1"></a>1</h1>\n' +
        '<h1><a name="p-1234-one-2" class="anchor" href="#p-1234-one-2"></a>one</h1>'
    );
  });

  test("bold and italics", function (assert) {
    assert.cooked(
      'a "**hello**"',
      "<p>a &quot;<strong>hello</strong>&quot;</p>",
      "bolds in quotes"
    );
    assert.cooked(
      "(**hello**)",
      "<p>(<strong>hello</strong>)</p>",
      "bolds in parens"
    );
    assert.cooked(
      "**hello**\nworld",
      "<p><strong>hello</strong><br>\nworld</p>",
      "allows newline after bold"
    );
    assert.cooked(
      "**hello**\n**world**",
      "<p><strong>hello</strong><br>\n<strong>world</strong></p>",
      "newline between two bolds"
    );
    assert.cooked(
      "** hello**",
      "<p>** hello**</p>",
      "does not bold on a space boundary"
    );
    assert.cooked(
      "**hello **",
      "<p>**hello **</p>",
      "does not bold on a space boundary"
    );
    assert.cooked(
      "**你hello**",
      "<p><strong>你hello</strong></p>",
      "allows bolded chinese"
    );
  });

  test("Escaping", function (assert) {
    assert.cooked(
      "*\\*laughs\\**",
      "<p><em>*laughs*</em></p>",
      "allows escaping strong"
    );
    assert.cooked(
      "*\\_laughs\\_*",
      "<p><em>_laughs_</em></p>",
      "allows escaping em"
    );
  });

  test("New Lines", function (assert) {
    // historically we would not continue inline em or b across lines,
    // however commonmark gives us no switch to do so and we would be very non compliant.
    // turning softbreaks into a newline is just a renderer option, not a parser switch.
    assert.cooked(
      "_abc\ndef_",
      "<p><em>abc<br>\ndef</em></p>",
      "does allow inlines to span new lines"
    );
    assert.cooked(
      "_abc\n\ndef_",
      "<p>_abc</p>\n<p>def_</p>",
      "does not allow inlines to span new paragraphs"
    );
  });

  test("Oneboxing", function (assert) {
    function matches(input, regexp) {
      return !!build().cook(input).match(regexp);
    }

    assert.false(
      matches(
        "- http://www.textfiles.com/bbs/MINDVOX/FORUMS/ethics\n\n- http://drupal.org",
        /class="onebox"/
      ),
      "doesn't onebox a link within a list"
    );

    assert.true(
      matches("http://test.com", /class="onebox"/),
      "adds a onebox class to a link on its own line"
    );
    assert.true(
      matches("http://test.com\nhttp://test2.com", /onebox[\s\S]+onebox/m),
      "supports multiple links"
    );
    assert.false(
      matches("http://test.com bob", /onebox/),
      "doesn't onebox links that have trailing text"
    );

    assert.false(
      matches("[Tom Cruise](http://www.tomcruise.com/)", "onebox"),
      "Markdown links with labels are not oneboxed"
    );
    assert.false(
      matches(
        "[http://www.tomcruise.com/](http://www.tomcruise.com/)",
        "onebox"
      ),
      "Markdown links where the label is the same as the url but link is explicit"
    );

    assert.cooked(
      "http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street",
      '<p><a href="http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street" class="onebox"' +
        ' target="_blank">http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street</a></p>',
      "works with links that have underscores in them"
    );
  });

  test("links with full urls", function (assert) {
    assert.cooked(
      "[http://eviltrout.com][1] is a url\n\n[1]: http://eviltrout.com",
      '<p><a href="http://eviltrout.com">http://eviltrout.com</a> is a url</p>',
      "supports links that are full URLs"
    );
  });

  test("Code Blocks", function (assert) {
    assert.cooked(
      "<pre>\nhello\n</pre>\n",
      "<pre>\nhello\n</pre>",
      "pre blocks don't include extra lines"
    );

    assert.cooked(
      "```\na\nb\nc\n\nd\n```",
      '<pre><code class="lang-auto">a\nb\nc\n\nd\n</code></pre>',
      "treats new lines properly"
    );

    assert.cooked(
      "```\ntest\n```",
      '<pre><code class="lang-auto">test\n</code></pre>',
      "supports basic code blocks"
    );

    assert.cooked(
      "```json\n{hello: 'world'}\n```\ntrailing",
      '<pre data-code-wrap="json"><code class="lang-json">{hello: \'world\'}\n</code></pre>\n<p>trailing</p>',
      "does not truncate text after a code block"
    );

    assert.cooked(
      "```json\nline 1\n\nline 2\n\n\nline3\n```",
      '<pre data-code-wrap="json"><code class="lang-json">line 1\n\nline 2\n\n\nline3\n</code></pre>',
      "maintains new lines inside a code block"
    );

    assert.cooked(
      "hello\nworld\n```json\nline 1\n\nline 2\n\n\nline3\n```",
      '<p>hello<br>\nworld</p>\n<pre data-code-wrap="json"><code class="lang-json">line 1\n\nline 2\n\n\nline3\n</code></pre>',
      "maintains new lines inside a code block with leading content"
    );

    assert.cooked(
      "```ruby\n<header>hello</header>\n```",
      '<pre data-code-wrap="ruby"><code class="lang-ruby">&lt;header&gt;hello&lt;/header&gt;\n</code></pre>',
      "escapes code in the code block"
    );

    assert.cooked(
      "```text\ntext\n```",
      '<pre><code class="lang-plaintext">text\n</code></pre>',
      "handles text by adding plaintext"
    );

    assert.cooked(
      "```ruby\n# cool\n```",
      '<pre data-code-wrap="ruby"><code class="lang-ruby"># cool\n</code></pre>',
      "supports changing the language"
    );

    assert.cooked(
      "    ```\n    hello\n    ```",
      "<pre><code>```\nhello\n```\n</code></pre>",
      "only detect ``` at the beginning of lines"
    );

    assert.cooked(
      "```ruby\ndef self.parse(text)\n\n  text\nend\n```",
      '<pre data-code-wrap="ruby"><code class="lang-ruby">def self.parse(text)\n\n  text\nend\n</code></pre>',
      "allows leading spaces on lines in a code block"
    );

    assert.cooked(
      "```ruby\nhello `eviltrout`\n```",
      '<pre data-code-wrap="ruby"><code class="lang-ruby">hello `eviltrout`\n</code></pre>',
      "allows code with backticks in it"
    );

    assert.cooked(
      "```eviltrout\nhello\n```",
      '<pre data-code-wrap="eviltrout"><code class="lang-eviltrout">hello\n</code></pre>',
      "converts to custom block unknown code names"
    );

    assert.cooked(
      '```\n[quote="sam, post:1, topic:9441, full:true"]This is `<not>` a bug.[/quote]\n```',
      '<pre><code class="lang-auto">[quote=&quot;sam, post:1, topic:9441, full:true&quot;]This is `&lt;not&gt;` a bug.[/quote]\n</code></pre>',
      "allows code with backticks in it"
    );

    assert.cooked(
      "    hello\n<blockquote>test</blockquote>",
      "<pre><code>hello\n</code></pre>\n<blockquote>test</blockquote>",
      "allows an indented code block to by followed by a `<blockquote>`"
    );

    assert.cooked(
      "``` foo bar ```",
      "<p><code>foo bar</code></p>",
      "tolerates misuse of code block tags as inline code"
    );

    assert.cooked(
      "```\nline1\n```\n```\nline2\n\nline3\n```",
      '<pre><code class="lang-auto">line1\n</code></pre>\n<pre><code class="lang-auto">line2\n\nline3\n</code></pre>',
      "does not consume next block's trailing newlines"
    );

    assert.cooked(
      "    <pre>test</pre>",
      "<pre><code>&lt;pre&gt;test&lt;/pre&gt;\n</code></pre>",
      "does not parse other block types in markdown code blocks"
    );

    assert.cooked(
      "    [quote]test[/quote]",
      "<pre><code>[quote]test[/quote]\n</code></pre>",
      "does not parse other block types in markdown code blocks"
    );

    assert.cooked(
      "## a\nb\n```\nc\n```",
      '<h2><a name="a-1" class="anchor" href="#a-1"></a>a</h2>\n<p>b</p>\n<pre><code class="lang-auto">c\n</code></pre>',
      "handles headings with code blocks after them"
    );
  });

  test("URLs in BBCode tags", function (assert) {
    assert.cooked(
      "[img]http://eviltrout.com/eviltrout.png[/img][img]http://samsaffron.com/samsaffron.png[/img]",
      '<p><img src="http://eviltrout.com/eviltrout.png" alt role="presentation"/><img src="http://samsaffron.com/samsaffron.png" alt role="presentation"/></p>',
      "images are properly parsed"
    );

    assert.cooked(
      "[url]http://discourse.org[/url]",
      '<p><a href="http://discourse.org" data-bbcode="true">http://discourse.org</a></p>',
      "links are properly parsed"
    );

    assert.cooked(
      "[url=http://discourse.org]discourse[/url]",
      '<p><a href="http://discourse.org" data-bbcode="true">discourse</a></p>',
      "named links are properly parsed"
    );

    assert.cooked(
      "[url]https://discourse.org/path[/url]",
      '<p><a href="https://discourse.org/path" data-bbcode="true">https://discourse.org/path</a></p>',
      "paths are correctly handled"
    );

    assert.cooked(
      "[url]discourse.org/path[/url]",
      '<p><a href="https://discourse.org/path" data-bbcode="true">discourse.org/path</a></p>',
      "paths are correctly handled"
    );

    assert.cooked(
      "[url][b]discourse.org/path[/b][/url]",
      '<p><a href="https://discourse.org/path" data-bbcode="true"><span class="bbcode-b">discourse.org/path</span></a></p>',
      "paths are correctly handled"
    );
  });

  test("images", function (assert) {
    assert.cooked(
      "[![folksy logo](http://folksy.com/images/folksy-colour.png)](http://folksy.com/)",
      '<p><a href="http://folksy.com/"><img src="http://folksy.com/images/folksy-colour.png" alt="folksy logo"/></a></p>',
      "allows images with links around them"
    );

    assert.cooked(
      '<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot">',
      '<p><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot"></p>',
      "allows data images"
    );

    assert.cooked(
      "![](http://folksy.com/images/folksy-colour.png)",
      '<p><img src="http://folksy.com/images/folksy-colour.png" alt role="presentation"></p>'
    );
  });

  test("attachment", function (assert) {
    assert.cooked(
      "[test.pdf|attachment](upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf)",
      `<p><a class="attachment" href="/404" data-orig-href="upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf">test.pdf</a></p>`,
      "returns the correct attachment link HTML"
    );
  });

  test("attachment - mapped url - secure uploads disabled", function (assert) {
    function lookupUploadUrls() {
      let cache = {};
      cache["upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf"] = {
        short_url: "upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf",
        url: "/secure-uploads/original/3X/c/b/o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf",
        short_path: "/uploads/short-url/blah",
      };
      return cache;
    }
    assert.cookedOptions(
      "[test.pdf|attachment](upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf)",
      {
        siteSettings: { secure_uploads: false },
        lookupUploadUrls,
      },
      `<p><a class="attachment" href="/uploads/short-url/blah">test.pdf</a></p>`,
      "returns the correct attachment link HTML when the URL is mapped without secure uploads"
    );
  });

  test("attachment - mapped url - secure uploads enabled", function (assert) {
    function lookupUploadUrls() {
      let cache = {};
      cache["upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf"] = {
        short_url: "upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf",
        url: "/secure-uploads/original/3X/c/b/o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf",
        short_path: "/uploads/short-url/blah",
      };
      return cache;
    }
    assert.cookedOptions(
      "[test.pdf|attachment](upload://o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf)",
      {
        siteSettings: { secure_uploads: true },
        lookupUploadUrls,
      },
      `<p><a class="attachment" href="/secure-uploads/original/3X/c/b/o8iobpLcW3WSFvVH7YQmyGlKmGM.pdf">test.pdf</a></p>`,
      "returns the correct attachment link HTML when the URL is mapped with secure uploads"
    );
  });

  test("video", function (assert) {
    assert.cooked(
      "![baby shark|video](upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp4)",
      `<p><div class="video-placeholder-container" data-video-src="/404" data-orig-src="upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp4">
  </div></p>`,
      "returns the correct video player HTML"
    );
  });

  test("video - mapped url - secure uploads enabled", function (assert) {
    function lookupUploadUrls() {
      let cache = {};
      cache["upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp4"] = {
        short_url: "upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp4",
        url: "/secure-uploads/original/3X/c/b/test.mp4",
        short_path: "/uploads/short-url/blah",
      };
      return cache;
    }
    assert.cookedOptions(
      "![baby shark|video](upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp4)",
      {
        siteSettings: { secure_uploads: true },
        lookupUploadUrls,
      },
      `<p><div class="video-placeholder-container" data-video-src="/secure-uploads/original/3X/c/b/test.mp4">
  </div></p>`,
      "returns the correct video HTML when the URL is mapped with secure uploads, removing data-orig-src"
    );
  });

  test("audio", function (assert) {
    assert.cooked(
      "![young americans|audio](upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp3)",
      `<p><audio preload="metadata" controls>
    <source src="/404" data-orig-src="upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp3">
    <a href="/404">/404</a>
  </audio></p>`,
      "returns the correct audio player HTML"
    );
  });

  test("audio - mapped url - secure uploads enabled", function (assert) {
    function lookupUploadUrls() {
      let cache = {};
      cache["upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp3"] = {
        short_url: "upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp3",
        url: "/secure-uploads/original/3X/c/b/test.mp3",
        short_path: "/uploads/short-url/blah",
      };
      return cache;
    }
    assert.cookedOptions(
      "![baby shark|audio](upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp3)",
      {
        siteSettings: { secure_uploads: true },
        lookupUploadUrls,
      },
      `<p><audio preload="metadata" controls>
    <source src="/secure-uploads/original/3X/c/b/test.mp3">
    <a href="/secure-uploads/original/3X/c/b/test.mp3">/secure-uploads/original/3X/c/b/test.mp3</a>
  </audio></p>`,
      "returns the correct audio HTML when the URL is mapped with secure uploads, removing data-orig-src"
    );
  });

  test("censoring", function (assert) {
    assert.cookedOptions(
      "Pleased to meet you, but pleeeease call me later, xyz123",
      {
        censoredRegexp: [{ "(xyz*|plee+ase)": { case_sensitive: false } }],
      },
      "<p>Pleased to meet you, but ■■■■■■■■■ call me later, ■■■123</p>",
      "supports censoring"
    );
    // More tests in pretty_text_spec.rb
  });

  test("code blocks/spans hoisting", function (assert) {
    assert.cooked(
      "```\n\n    some code\n```",
      '<pre><code class="lang-auto">\n    some code\n</code></pre>',
      "works when nesting standard markdown code blocks within a fenced code block"
    );

    assert.cooked(
      "`$&`",
      "<p><code>$&amp;</code></p>",
      "works even when hoisting special replacement patterns"
    );
  });

  test("basic bbcode", function (assert) {
    assert.cookedPara(
      "[b]strong[/b]",
      '<span class="bbcode-b">strong</span>',
      "bolds text"
    );
    assert.cookedPara(
      "[i]emphasis[/i]",
      '<span class="bbcode-i">emphasis</span>',
      "italics text"
    );
    assert.cookedPara(
      "[u]underlined[/u]",
      '<span class="bbcode-u">underlined</span>',
      "underlines text"
    );
    assert.cookedPara(
      "[s]strikethrough[/s]",
      '<span class="bbcode-s">strikethrough</span>',
      "strikes-through text"
    );
    assert.cookedPara(
      "[img]http://eviltrout.com/eviltrout.png[/img]",
      '<img src="http://eviltrout.com/eviltrout.png" alt role="presentation">',
      "links images"
    );
    assert.cookedPara(
      "[email]eviltrout@mailinator.com[/email]",
      '<a href="mailto:eviltrout@mailinator.com" data-bbcode="true">eviltrout@mailinator.com</a>',
      "supports [email] without a title"
    );
    assert.cookedPara(
      "[b]evil [i]trout[/i][/b]",
      '<span class="bbcode-b">evil <span class="bbcode-i">trout</span></span>',
      "allows embedding of tags"
    );
    assert.cookedPara(
      "[EMAIL]eviltrout@mailinator.com[/EMAIL]",
      '<a href="mailto:eviltrout@mailinator.com" data-bbcode="true">eviltrout@mailinator.com</a>',
      "supports upper case bbcode"
    );
    assert.cookedPara(
      "[b]strong [b]stronger[/b][/b]",
      '<span class="bbcode-b">strong <span class="bbcode-b">stronger</span></span>',
      "accepts nested bbcode tags"
    );
  });

  test("urls", function (assert) {
    assert.cookedPara(
      "[url]not a url[/url]",
      "not a url",
      "supports [url] that isn't a url"
    );
    assert.cookedPara(
      "[url]abc.com[/url]",
      '<a href="https://abc.com" data-bbcode="true">abc.com</a>',
      "magically links using linkify"
    );
    assert.cookedPara(
      "[url]http://bettercallsaul.com[/url]",
      '<a href="http://bettercallsaul.com" data-bbcode="true">http://bettercallsaul.com</a>',
      "supports [url] without parameter"
    );
    assert.cookedPara(
      "[url=http://example.com]example[/url]",
      '<a href="http://example.com" data-bbcode="true">example</a>',
      "supports [url] with given href"
    );
    assert.cookedPara(
      "[url=http://www.example.com][img]http://example.com/logo.png[/img][/url]",
      '<a href="http://www.example.com" data-bbcode="true"><img src="http://example.com/logo.png" alt role="presentation"></a>',
      "supports [url] with an embedded [img]"
    );
  });
  test("invalid bbcode", function (assert) {
    assert.cooked(
      "[code]I am not closed\n\nThis text exists.",
      "<p>[code]I am not closed</p>\n<p>This text exists.</p>",
      "does not raise an error with an open bbcode tag"
    );
  });

  test("code", function (assert) {
    assert.cooked(
      "[code]\nx++\n[/code]",
      '<pre><code class="lang-auto">x++</code></pre>',
      "makes code into pre"
    );
    assert.cooked(
      "[code]\nx++\ny++\nz++\n[/code]",
      '<pre><code class="lang-auto">x++\ny++\nz++</code></pre>',
      "makes code into pre"
    );
    assert.cooked(
      "[code]\nabc\n#def\n[/code]",
      '<pre><code class="lang-auto">abc\n#def</code></pre>',
      "handles headings in a [code] block"
    );
    assert.cooked(
      "[code]\n   s\n[/code]",
      '<pre><code class="lang-auto">   s</code></pre>',
      "doesn't trim leading whitespace"
    );
    assert.cooked(
      "> [code]\n> line 1\n> line 2\n> line 3\n> [/code]",
      '<blockquote>\n<pre><code class="lang-auto">line 1\nline 2\nline 3</code></pre>\n</blockquote>',
      "supports quoting a whole [code] block"
    );
  });

  test("tags with arguments", function (assert) {
    assert.cookedPara(
      "[url=http://bettercallsaul.com]better call![/url]",
      '<a href="http://bettercallsaul.com" data-bbcode="true">better call!</a>',
      "supports [url] with a title"
    );
    assert.cookedPara(
      "[email=eviltrout@mailinator.com]evil trout[/email]",
      '<a href="mailto:eviltrout@mailinator.com" data-bbcode="true">evil trout</a>',
      "supports [email] with a title"
    );
    assert.cookedPara(
      "[u][i]abc[/i][/u]",
      '<span class="bbcode-u"><span class="bbcode-i">abc</span></span>',
      "can nest tags"
    );
    assert.cookedPara(
      "[b]first[/b] [b]second[/b]",
      '<span class="bbcode-b">first</span> <span class="bbcode-b">second</span>',
      "can bold two things on the same line"
    );
  });

  test("quote formatting", function (assert) {
    assert.cooked(
      '[quote="EvilTrout, post:123, topic:456, full:true"]\n[sam]\n[/quote]',
      `<aside class=\"quote no-group\" data-username=\"EvilTrout\" data-post=\"123\" data-topic=\"456\" data-full=\"true\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 EvilTrout:</div>
<blockquote>
<p>[sam]</p>
</blockquote>
</aside>`,
      "allows quotes with [] inside"
    );

    assert.cooked(
      '[quote="eviltrout, post:1, topic:1"]\nabc\n[/quote]',
      `<aside class=\"quote no-group\" data-username=\"eviltrout\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 eviltrout:</div>
<blockquote>
<p>abc</p>
</blockquote>
</aside>`,
      "renders quotes properly"
    );

    assert.cooked(
      '[quote="eviltrout, post:1, topic:1"]\nabc\n[/quote]\nhello',
      `<aside class=\"quote no-group\" data-username=\"eviltrout\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 eviltrout:</div>
<blockquote>
<p>abc</p>
</blockquote>
</aside>
<p>hello</p>`,
      "handles new lines properly"
    );

    assert.cooked(
      '[quote="Alice, post:1, topic:1"]\n[quote="Bob, post:2, topic:1"]\n[/quote]\n[/quote]',
      `<aside class=\"quote no-group\" data-username=\"Alice\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Alice:</div>
<blockquote>
<aside class=\"quote no-group\" data-username=\"Bob\" data-post=\"2\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Bob:</div>
<blockquote></blockquote>
</aside>
</blockquote>
</aside>`,
      "quotes can be nested"
    );

    assert.cooked(
      '[quote="Alice, post:1, topic:1"]\n[quote="Bob, post:2, topic:1"]\n[/quote]',
      `<p>[quote=&quot;Alice, post:1, topic:1&quot;]</p>
<aside class=\"quote no-group\" data-username=\"Bob\" data-post=\"2\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Bob:</div>
<blockquote></blockquote>
</aside>`,
      "handles mismatched nested quote tags (non greedy)"
    );

    assert.cooked(
      "[quote=\"Alice, post:1, topic:1\"]\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
      `<aside class=\"quote no-group\" data-username=\"Alice\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Alice:</div>
<blockquote>
<pre data-code-wrap=\"javascript\"><code class=\"lang-javascript\">var foo ='foo';
var bar = 'bar';
</code></pre>
</blockquote>
</aside>`,
      "quotes can have code blocks without leading newline"
    );

    assert.cooked(
      "[quote=\"Alice, post:1, topic:1\"]\n\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
      `<aside class=\"quote no-group\" data-username=\"Alice\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Alice:</div>
<blockquote>
<pre data-code-wrap=\"javascript\"><code class=\"lang-javascript\">var foo ='foo';
var bar = 'bar';
</code></pre>
</blockquote>
</aside>`,
      "quotes can have code blocks with leading newline"
    );
  });

  test("quotes with trailing formatting", function (assert) {
    const result = build().cook(
      '[quote="EvilTrout, post:123, topic:456, full:true"]\nhello\n[/quote]\n*Test*'
    );
    assert.strictEqual(
      result,
      `<aside class=\"quote no-group\" data-username=\"EvilTrout\" data-post=\"123\" data-topic=\"456\" data-full=\"true\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 EvilTrout:</div>
<blockquote>
<p>hello</p>
</blockquote>
</aside>
<p><em>Test</em></p>`,
      "allows trailing formatting"
    );
  });

  test("enable/disable features", function (assert) {
    assert.cookedOptions("|a|\n--\n|a|", { features: { table: false } }, "");
    assert.cooked(
      "|a|\n--\n|a|",
      `<div class="md-table">
<table>
<thead>
<tr>
<th>a</th>
</tr>
</thead>
<tbody>
<tr>
<td>a</td>
</tr>
</tbody>
</table>
</div>`
    );
  });

  test("customizing markdown-it rules", function (assert) {
    assert.cookedOptions(
      "**bold**",
      { markdownItRules: [] },
      "<p>**bold**</p>",
      "does not apply bold markdown when rule is not enabled"
    );

    assert.cookedOptions(
      "**bold**",
      { markdownItRules: ["emphasis"] },
      "<p><strong>bold</strong></p>",
      "applies bold markdown when rule is enabled"
    );
  });

  test("features override", function (assert) {
    assert.cookedOptions(
      ":grin: @sam",
      { featuresOverride: [] },
      "<p>:grin: @sam</p>",
      "does not cook emojis when Discourse markdown engines are disabled"
    );

    assert.cookedOptions(
      ":grin: @sam",
      { featuresOverride: ["emoji"] },
      `<p><img src="/images/emoji/twitter/grin.png?v=${v}" title=":grin:" class="emoji" alt=":grin:" loading="lazy" width="20" height="20"> @sam</p>`,
      "cooks emojis when only the emoji markdown engine is enabled"
    );

    assert.cookedOptions(
      ":grin: @sam",
      { featuresOverride: ["mentions", "text-post-process"] },
      `<p>:grin: <span class="mention">@sam</span></p>`,
      "cooks mentions when only the mentions markdown engine is enabled"
    );
  });

  test("emoji", function (assert) {
    assert.cooked(
      ":smile:",
      `<p><img src="/images/emoji/twitter/smile.png?v=${v}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>`
    );
    assert.cooked(
      ":(",
      `<p><img src="/images/emoji/twitter/frowning.png?v=${v}" title=":frowning:" class="emoji only-emoji" alt=":frowning:" loading="lazy" width="20" height="20"></p>`
    );
    assert.cooked(
      "8-)",
      `<p><img src="/images/emoji/twitter/sunglasses.png?v=${v}" title=":sunglasses:" class="emoji only-emoji" alt=":sunglasses:" loading="lazy" width="20" height="20"></p>`
    );
  });

  test("emoji - enable_inline_emoji_translation", function (assert) {
    assert.cookedOptions(
      "test:smile:test",
      { siteSettings: { enable_inline_emoji_translation: false } },
      `<p>test:smile:test</p>`
    );

    assert.cookedOptions(
      "test:smile:test",
      { siteSettings: { enable_inline_emoji_translation: true } },
      `<p>test<img src="/images/emoji/twitter/smile.png?v=${v}" title=":smile:" class="emoji" alt=":smile:" loading="lazy" width="20" height="20">test</p>`
    );
  });

  test("emoji - emojiSet", function (assert) {
    assert.cookedOptions(
      ":smile:",
      { siteSettings: { emoji_set: "twitter" } },
      `<p><img src="/images/emoji/twitter/smile.png?v=${v}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>`
    );
  });

  test("emoji - emojiCDN", function (assert) {
    assert.cookedOptions(
      ":smile:",
      {
        siteSettings: {
          emoji_set: "twitter",
          external_emoji_url: "https://emoji.hosting.service",
        },
      },
      `<p><img src="https://emoji.hosting.service/twitter/smile.png?v=${v}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>`
    );
  });

  test("emoji - registerEmoji", function (assert) {
    registerEmoji("foo", "/images/d-logo-sketch.png");

    assert.cookedOptions(
      ":foo:",
      {},
      `<p><img src="/images/d-logo-sketch.png?v=${v}" title=":foo:" class="emoji emoji-custom only-emoji" alt=":foo:" loading="lazy" width="20" height="20"></p>`
    );

    registerEmoji("bar", "/images/avatar.png", "baz");

    assert.cookedOptions(
      ":bar:",
      {},
      `<p><img src="/images/avatar.png?v=${v}" title=":bar:" class="emoji emoji-custom only-emoji" alt=":bar:" loading="lazy" width="20" height="20"></p>`
    );
  });

  test("extractDataAttribute", function (assert) {
    assert.deepEqual(extractDataAttribute("foo="), ["data-foo", ""]);
    assert.deepEqual(extractDataAttribute("foo=bar"), ["data-foo", "bar"]);

    assert.strictEqual(extractDataAttribute("foo?=bar"), null);
    assert.strictEqual(
      extractDataAttribute("https://discourse.org/?q=hello"),
      null
    );
  });

  test("video - display placeholder when previewing", function (assert) {
    assert.cookedOptions(
      `![baby shark|video](upload://eyPnj7UzkU0AkGkx2dx8G4YM1Jx.mp4)`,
      { previewing: true },
      `<p><div class="onebox-placeholder-container" data-orig-src-id="eyPnj7UzkU0AkGkx2dx8G4YM1Jx">
        <span class="placeholder-icon video"></span>
      </div></p>`
    );
  });

  test("typographer arrows", function (assert) {
    const enabledTypographer = {
      siteSettings: { enable_markdown_typographer: true },
    };

    // Replace arrows
    assert.cookedOptions(
      "--> <--",
      enabledTypographer,
      "<p> \u2192 \u2190 </p>"
    );
    assert.cookedOptions("a -> b", enabledTypographer, "<p>a \u2192 b</p>");
    assert.cookedOptions("a <- b", enabledTypographer, "<p>a \u2190 b</p>");
    assert.cookedOptions("a --> b", enabledTypographer, "<p>a \u2192 b</p>");
    assert.cookedOptions("-->", enabledTypographer, "<p> \u2192 </p>");
    assert.cookedOptions("<--", enabledTypographer, "<p> \u2190 </p>");
    assert.cookedOptions("<->", enabledTypographer, "<p> \u2194 </p>");
    assert.cookedOptions("<-->", enabledTypographer, "<p> \u2194 </p>");

    // Don't replace arrows
    assert.cookedOptions("<!-- an html comment -->", enabledTypographer, "");
    assert.cookedOptions(
      "(<--not an arrow)",
      enabledTypographer,
      "<p>(&lt;–not an arrow)</p>"
    );
    assert.cookedOptions("asd-->", enabledTypographer, "<p>asd–&gt;</p>");
    assert.cookedOptions(" asd--> ", enabledTypographer, "<p>asd–&gt;</p>");
    assert.cookedOptions(" asd-->", enabledTypographer, "<p>asd–&gt;</p>");
    assert.cookedOptions("-->asd", enabledTypographer, "<p>–&gt;asd</p>");
    assert.cookedOptions(" -->asd ", enabledTypographer, "<p>–&gt;asd</p>");
    assert.cookedOptions(" -->asd", enabledTypographer, "<p>–&gt;asd</p>");
  });

  test("default typographic replacements", function (assert) {
    const enabledTypographer = {
      siteSettings: { enable_markdown_typographer: true },
    };

    assert.cookedOptions("(bad)", enabledTypographer, "<p>(bad)</p>");
    assert.cookedOptions("+-5", enabledTypographer, "<p>±5</p>");
    assert.cookedOptions(
      "test.. test... test..... test?..... test!...",
      enabledTypographer,
      "<p>test… test… test… test?.. test!..</p>"
    );
    assert.cookedOptions(
      "!!!!!! ???? ,,",
      enabledTypographer,
      "<p>!!! ??? ,</p>"
    );
    assert.cookedOptions(
      "!!!!!! ???? ,,",
      enabledTypographer,
      "<p>!!! ??? ,</p>"
    );
    assert.cookedOptions("(tm) (TM)", enabledTypographer, "<p>™ ™</p>");
    assert.cookedOptions("(pa) (PA)", enabledTypographer, "<p>¶ ¶</p>");
  });

  test("default typographic replacements - dashes", function (assert) {
    const enabledTypographer = {
      siteSettings: { enable_markdown_typographer: true },
    };

    assert.cookedOptions(
      "---markdownit --- super---",
      enabledTypographer,
      "<p>—markdownit — super—</p>"
    );
    assert.cookedOptions(
      "markdownit---awesome",
      enabledTypographer,
      "<p>markdownit—awesome</p>"
    );
    assert.cookedOptions("abc ----", enabledTypographer, "<p>abc ----</p>");
    assert.cookedOptions(
      "--markdownit -- super--",
      enabledTypographer,
      "<p>–markdownit – super–</p>"
    );
    assert.cookedOptions(
      "markdownit--awesome",
      enabledTypographer,
      "<p>markdownit–awesome</p>"
    );
    assert.cookedOptions("1---2---3", enabledTypographer, "<p>1—2—3</p>");
    assert.cookedOptions("1--2--3", enabledTypographer, "<p>1–2–3</p>");
    assert.cookedOptions(
      "<p>1 – – 3</p>",
      enabledTypographer,
      "<p>1 – – 3</p>"
    );
  });

  test("disabled typographic replacements", function (assert) {
    const enabledTypographer = {
      siteSettings: { enable_markdown_typographer: true },
    };

    assert.cookedOptions("(c) (C)", enabledTypographer, "<p>(c) (C)</p>");
    assert.cookedOptions("(r) (R)", enabledTypographer, "<p>(r) (R)</p>");
    assert.cookedOptions("(p) (P)", enabledTypographer, "<p>(p) (P)</p>");
  });

  test("watched words replace", function (assert) {
    const opts = {
      watchedWordsReplace: {
        "(?:\\W|^)(fun)(?=\\W|$)": {
          word: "fun",
          replacement: "times",
          case_sensitive: false,
        },
      },
    };

    assert.cookedOptions("test fun funny", opts, "<p>test times funny</p>");
    assert.cookedOptions("constructor", opts, "<p>constructor</p>");
  });

  test("watched words link", function (assert) {
    const opts = {
      watchedWordsLink: {
        "(?:\\W|^)(fun)(?=\\W|$)": {
          word: "fun",
          replacement: "https://discourse.org",
          case_sensitive: false,
        },
      },
    };

    assert.cookedOptions(
      "test fun funny",
      opts,
      '<p>test <a href="https://discourse.org">fun</a> funny</p>'
    );
  });

  test("watched words replace with bad regex", function (assert) {
    const opts = {
      siteSettings: { watched_words_regular_expressions: true },
      watchedWordsReplace: {
        "(\\bu?\\b)": {
          word: "(\\bu?\\b)",
          replacement: "you",
          case_sensitive: false,
        },
      },
    };

    assert.cookedOptions(
      "one",
      opts,
      `<p>youoneyou</p>`,
      "does not loop infinitely"
    );
  });

  test("highlighted aliased languages", function (assert) {
    // "js" is an alias of "javascript"
    assert.cooked(
      "```js\nvar foo ='foo';\nvar bar = 'bar';\n```",
      `<pre data-code-wrap="js"><code class=\"lang-js\">var foo ='foo';
var bar = 'bar';
</code></pre>`,
      "code block with js alias works"
    );

    // "html" is an alias of "xml"
    assert.cooked(
      "```html\n<strong>fun</strong> times\n```",
      `<pre data-code-wrap="html"><code class=\"lang-html\">&lt;strong&gt;fun&lt;/strong&gt; times
</code></pre>`,
      "code block with html alias work"
    );
  });

  test("image grid", function (assert) {
    assert.cooked(
      "[grid]\n![](http://folksy.com/images/folksy-colour.png)\n[/grid]",
      `<div class="d-image-grid">
<p><img src="http://folksy.com/images/folksy-colour.png" alt role="presentation"></p>
</div>`,
      "image grid works"
    );

    assert.cooked(
      `[grid]
![](http://folksy.com/images/folksy-colour.png)
![](http://folksy.com/images/folksy-colour2.png)
![](http://folksy.com/images/folksy-colour3.png)
[/grid]`,
      `<div class="d-image-grid">
<p><img src="http://folksy.com/images/folksy-colour.png" alt role="presentation"><br>
<img src="http://folksy.com/images/folksy-colour2.png" alt role="presentation"><br>
<img src="http://folksy.com/images/folksy-colour3.png" alt role="presentation"></p>
</div>`,
      "image grid with 3 images works"
    );

    assert.cooked(
      `[grid]
![](http://folksy.com/images/folksy-colour.png) ![](http://folksy.com/images/folksy-colour2.png)
![](http://folksy.com/images/folksy-colour3.png)
[/grid]`,
      `<div class="d-image-grid">
<p><img src="http://folksy.com/images/folksy-colour.png" alt role="presentation"> <img src="http://folksy.com/images/folksy-colour2.png" alt role="presentation"><br>
<img src="http://folksy.com/images/folksy-colour3.png" alt role="presentation"></p>
</div>`,
      "image grid with mixed block and inline images works"
    );

    assert.cooked(
      "[grid]![](http://folksy.com/images/folksy-colour.png) ![](http://folksy.com/images/folksy-colour2.png)[/grid]",
      `<div class="d-image-grid">
<p><img src="http://folksy.com/images/folksy-colour.png" alt role="presentation"> <img src="http://folksy.com/images/folksy-colour2.png" alt role="presentation"></p>
</div>`,
      "image grid with inline images works"
    );
  });
});
