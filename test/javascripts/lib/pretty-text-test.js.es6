import Quote from "discourse/lib/quote";
import Post from "discourse/models/post";
import { default as PrettyText, buildOptions } from "pretty-text/pretty-text";
import { IMAGE_VERSION as v } from "pretty-text/emoji";
import { INLINE_ONEBOX_LOADING_CSS_CLASS } from "pretty-text/inline-oneboxer";

QUnit.module("lib:pretty-text");

const rawOpts = {
  siteSettings: {
    enable_emoji: true,
    enable_emoji_shortcuts: true,
    enable_mentions: true,
    emoji_set: "emoji_one",
    highlighted_languages: "json|ruby|javascript",
    default_code_lang: "auto",
    enable_markdown_linkify: true,
    markdown_linkify_tlds: "com"
  },
  censoredWords: "shucks|whiz|whizzer|a**le|badword*|shuck$|café|$uper",
  getURL: url => url
};

const defaultOpts = buildOptions(rawOpts);

QUnit.assert.cooked = function(input, expected, message) {
  const actual = new PrettyText(defaultOpts).cook(input);
  this.pushResult({
    result: actual === expected.replace(/\/>/g, ">"),
    actual,
    expected,
    message
  });
};

QUnit.assert.cookedOptions = function(input, opts, expected, message) {
  const merged = _.merge({}, rawOpts, opts);
  const actual = new PrettyText(buildOptions(merged)).cook(input);
  this.pushResult({
    result: actual === expected,
    actual,
    expected,
    message
  });
};

QUnit.assert.cookedPara = function(input, expected, message) {
  QUnit.assert.cooked(input, `<p>${expected}</p>`, message);
};

QUnit.skip("Pending Engine fixes and spec fixes", assert => {
  assert.cooked(
    "Derpy: http://derp.com?_test_=1",
    '<p>Derpy: <a href=https://derp.com?_test_=1"http://derp.com?_test_=1">http://derp.com?_test_=1</a></p>',
    "works with underscores in urls"
  );

  assert.cooked(
    "**a*_b**",
    "<p><strong>a*_b</strong></p>",
    "allows for characters within bold"
  );
});

QUnit.test("buildOptions", assert => {
  assert.ok(
    buildOptions({ siteSettings: { enable_emoji: true } }).discourse.features
      .emoji,
    "emoji enabled"
  );
  assert.ok(
    !buildOptions({ siteSettings: { enable_emoji: false } }).discourse.features
      .emoji,
    "emoji disabled"
  );
});

QUnit.test("basic cooking", assert => {
  assert.cooked("hello", "<p>hello</p>", "surrounds text with paragraphs");
  assert.cooked("**evil**", "<p><strong>evil</strong></p>", "it bolds text.");
  assert.cooked("__bold__", "<p><strong>bold</strong></p>", "it bolds text.");
  assert.cooked("*trout*", "<p><em>trout</em></p>", "it italicizes text.");
  assert.cooked("_trout_", "<p><em>trout</em></p>", "it italicizes text.");
  assert.cooked(
    "***hello***",
    "<p><em><strong>hello</strong></em></p>",
    "it can do bold and italics at once."
  );
  assert.cooked(
    "word_with_underscores",
    "<p>word_with_underscores</p>",
    "it doesn't do intraword italics"
  );
  assert.cooked(
    "common/_special_font_face.html.erb",
    "<p>common/_special_font_face.html.erb</p>",
    "it doesn't intraword with a slash"
  );
  assert.cooked(
    "hello \\*evil\\*",
    "<p>hello *evil*</p>",
    "it supports escaping of asterisks"
  );
  assert.cooked(
    "hello \\_evil\\_",
    "<p>hello _evil_</p>",
    "it supports escaping of italics"
  );
  assert.cooked(
    "brussels sprouts are *awful*.",
    "<p>brussels sprouts are <em>awful</em>.</p>",
    "it doesn't swallow periods."
  );
});

QUnit.test("Nested bold and italics", assert => {
  assert.cooked(
    "*this is italic **with some bold** inside*",
    "<p><em>this is italic <strong>with some bold</strong> inside</em></p>",
    "it handles nested bold in italics"
  );
});

QUnit.test("Traditional Line Breaks", assert => {
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

QUnit.test("Unbalanced underscores", assert => {
  assert.cooked(
    "[evil_trout][1] hello_\n\n[1]: http://eviltrout.com",
    '<p><a href="http://eviltrout.com">evil_trout</a> hello_</p>'
  );
});

QUnit.test("Line Breaks", assert => {
  assert.cooked(
    "[] first choice\n[] second choice",
    "<p>[] first choice<br>\n[] second choice</p>",
    "it handles new lines correctly with [] options"
  );

  // note this is a change from previous engine but is correct
  // we have an html block and behavior is defined per common mark
  // spec
  // ole engine would wrap trout in a <p>
  assert.cooked(
    "<blockquote>evil</blockquote>\ntrout",
    "<blockquote>evil</blockquote>\ntrout",
    "it doesn't insert <br> after blockquotes"
  );

  assert.cooked(
    "leading<blockquote>evil</blockquote>\ntrout",
    "<p>leading<blockquote>evil</blockquote><br>\ntrout</p>",
    "it doesn't insert <br> after blockquotes with leading text"
  );
});

QUnit.test("Paragraphs for HTML", assert => {
  assert.cooked(
    "<div>hello world</div>",
    "<div>hello world</div>",
    "it doesn't surround <div> with paragraphs"
  );
  assert.cooked(
    "<p>hello world</p>",
    "<p>hello world</p>",
    "it doesn't surround <p> with paragraphs"
  );
  assert.cooked(
    "<i>hello world</i>",
    "<p><i>hello world</i></p>",
    "it surrounds inline <i> html tags with paragraphs"
  );
  assert.cooked(
    "<b>hello world</b>",
    "<p><b>hello world</b></p>",
    "it surrounds inline <b> html tags with paragraphs"
  );
});

QUnit.test("Links", assert => {
  assert.cooked(
    "EvilTrout: http://eviltrout.com",
    '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a></p>',
    "autolinks a URL"
  );

  assert.cooked(
    "Youtube: http://www.youtube.com/watch?v=1MrpeBRkM5A",
    `<p>Youtube: <a href="http://www.youtube.com/watch?v=1MrpeBRkM5A" class="${INLINE_ONEBOX_LOADING_CSS_CLASS}">http://www.youtube.com/watch?v=1MrpeBRkM5A</a></p>`,
    "allows links to contain query params"
  );

  assert.cooked(
    "Derpy: http://derp.com?__test=1",
    `<p>Derpy: <a href="http://derp.com?__test=1" class="${INLINE_ONEBOX_LOADING_CSS_CLASS}">http://derp.com?__test=1</a></p>`,
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
    `<p>Batman: <a href="http://en.wikipedia.org/wiki/The_Dark_Knight_(film)" class="${INLINE_ONEBOX_LOADING_CSS_CLASS}">http://en.wikipedia.org/wiki/The_Dark_Knight_(film)</a></p>`,
    "autolinks a URL with parentheses (like Wikipedia)"
  );

  assert.cooked(
    "Here's a tweet:\nhttps://twitter.com/evil_trout/status/345954894420787200",
    '<p>Here\'s a tweet:<br>\n<a href="https://twitter.com/evil_trout/status/345954894420787200" class="onebox" target="_blank">https://twitter.com/evil_trout/status/345954894420787200</a></p>',
    "It doesn't strip the new line."
  );

  assert.cooked(
    "1. View @eviltrout's profile here: http://meta.discourse.org/u/eviltrout/activity<br/>next line.",
    `<ol>\n<li>View <span class="mention">@eviltrout</span>\'s profile here: <a href="http://meta.discourse.org/u/eviltrout/activity" class="${INLINE_ONEBOX_LOADING_CSS_CLASS}">http://meta.discourse.org/u/eviltrout/activity</a><br>next line.</li>\n</ol>`,
    "allows autolinking within a list without inserting a paragraph."
  );

  assert.cooked(
    "[3]: http://eviltrout.com",
    "",
    "It doesn't autolink markdown link references"
  );

  assert.cooked(
    "[]: http://eviltrout.com",
    '<p>[]: <a href="http://eviltrout.com">http://eviltrout.com</a></p>',
    "It doesn't accept empty link references"
  );

  assert.cooked(
    "[b]label[/b]: description",
    '<p><span class="bbcode-b">label</span>: description</p>',
    "It doesn't accept BBCode as link references"
  );

  assert.cooked(
    "http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369",
    '<p><a href="http://discourse.org">http://discourse.org</a> and ' +
      `<a href="http://discourse.org/another_url" class="${INLINE_ONEBOX_LOADING_CSS_CLASS}">http://discourse.org/another_url</a> and ` +
      `<a href="http://www.imdb.com/name/nm2225369" class="${INLINE_ONEBOX_LOADING_CSS_CLASS}">http://www.imdb.com/name/nm2225369</a></p>`,
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
    "It does not consider references that are obviously not URLs"
  );

  assert.cooked(
    "<small>http://eviltrout.com</small>",
    '<p><small><a href="http://eviltrout.com">http://eviltrout.com</a></small></p>',
    "Links within HTML tags"
  );

  assert.cooked(
    "[http://google.com ... wat](http://discourse.org)",
    '<p><a href="http://discourse.org">http://google.com ... wat</a></p>',
    "it supports links within links"
  );

  assert.cooked(
    "[http://google.com](http://discourse.org)",
    '<p><a href="http://discourse.org">http://google.com</a></p>',
    "it supports markdown links where the name and link match"
  );

  assert.cooked(
    '[Link](http://www.example.com) (with an outer "description")',
    '<p><a href="http://www.example.com">Link</a> (with an outer &quot;description&quot;)</p>',
    "it doesn't consume closing parens as part of the url"
  );

  assert.cooked(
    "A link inside parentheses (http://www.example.com)",
    '<p>A link inside parentheses (<a href="http://www.example.com">http://www.example.com</a>)</p>',
    "it auto-links a url within parentheses"
  );

  assert.cooked(
    "[ul][1]\n\n[1]: http://eviltrout.com",
    '<p><a href="http://eviltrout.com">ul</a></p>',
    "it can use `ul` as a link name"
  );
});

QUnit.test("simple quotes", assert => {
  assert.cooked(
    "> nice!",
    "<blockquote>\n<p>nice!</p>\n</blockquote>",
    "it supports simple quotes"
  );
  assert.cooked(
    " > nice!",
    "<blockquote>\n<p>nice!</p>\n</blockquote>",
    "it allows quotes with preceding spaces"
  );
  assert.cooked(
    "> level 1\n> > level 2",
    "<blockquote>\n<p>level 1</p>\n<blockquote>\n<p>level 2</p>\n</blockquote>\n</blockquote>",
    "it allows nesting of blockquotes"
  );
  assert.cooked(
    "> level 1\n>  > level 2",
    "<blockquote>\n<p>level 1</p>\n<blockquote>\n<p>level 2</p>\n</blockquote>\n</blockquote>",
    "it allows nesting of blockquotes with spaces"
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
    "it allows quotes within a list."
  );

  assert.cooked(
    "- <p>eviltrout</p>",
    "<ul>\n<li>\n<p>eviltrout</p></li>\n</ul>",
    "it allows paragraphs within a list."
  );

  assert.cooked(
    "  > indent 1\n  > indent 2",
    "<blockquote>\n<p>indent 1<br>\nindent 2</p>\n</blockquote>",
    "allow multiple spaces to indent"
  );
});

QUnit.test("Quotes", assert => {
  assert.cookedOptions(
    '[quote="eviltrout, post: 1"]\na quote\n\nsecond line\n\nthird line\n[/quote]',
    { topicId: 2 },
    `<aside class=\"quote no-group\" data-post=\"1\">
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
    { topicId: 2, lookupAvatar: function() {} },
    `<aside class=\"quote no-group\" data-post=\"1\">
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
    `<aside class="quote group-aUserGroup" data-post="1" data-topic="1">
<div class="title">
<div class="quote-controls"></div>
 bob:</div>
<blockquote>
<p>test quote</p>
</blockquote>
</aside>`,
    "quote has group class"
  );
});

QUnit.test("Mentions", assert => {
  assert.cooked(
    "Hello @sam",
    '<p>Hello <span class="mention">@sam</span></p>',
    "translates mentions to links"
  );

  assert.cooked(
    "[@codinghorror](https://twitter.com/codinghorror)",
    '<p><a href="https://twitter.com/codinghorror">@codinghorror</a></p>',
    "it doesn't do mentions within links"
  );

  assert.cooked(
    "[@codinghorror](https://twitter.com/codinghorror)",
    '<p><a href="https://twitter.com/codinghorror">@codinghorror</a></p>',
    "it doesn't do link mentions within links"
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
    "it handles mentions at the beginning of a string"
  );

  assert.cooked(
    "yo\n@EvilTrout",
    '<p>yo<br>\n<span class="mention">@EvilTrout</span></p>',
    "it handles mentions at the beginning of a new line"
  );

  assert.cooked(
    "`evil` @EvilTrout `trout`",
    '<p><code>evil</code> <span class="mention">@EvilTrout</span> <code>trout</code></p>',
    "deals correctly with multiple <code> blocks"
  );

  assert.cooked(
    "```\na @test\n```",
    '<pre><code class="lang-auto">a @test\n</code></pre>',
    "should not do mentions within a code block."
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
    "you can have a mention in an inline code block following a real mention."
  );

  assert.cooked(
    "1. this is  a list\n\n2. this is an @eviltrout mention\n",
    '<ol>\n<li>\n<p>this is  a list</p>\n</li>\n<li>\n<p>this is an <span class="mention">@eviltrout</span> mention</p>\n</li>\n</ol>',
    "it mentions properly in a list."
  );

  assert.cooked(
    "Hello @foo/@bar",
    '<p>Hello <span class="mention">@foo</span>/<span class="mention">@bar</span></p>',
    "handles mentions separated by a slash."
  );

  assert.cooked(
    "<small>a @sam c</small>",
    '<p><small>a <span class="mention">@sam</span> c</small></p>',
    "it allows mentions within HTML tags"
  );
});

QUnit.test("Mentions - disabled", assert => {
  assert.cookedOptions(
    "@eviltrout",
    { siteSettings: { enable_mentions: false } },
    "<p>@eviltrout</p>"
  );
});

QUnit.test("Category hashtags", assert => {
  const alwaysTrue = {
    categoryHashtagLookup: function() {
      return ["http://test.discourse.org/category-hashtag", "category-hashtag"];
    }
  };

  assert.cookedOptions(
    "Check out #category-hashtag",
    alwaysTrue,
    '<p>Check out <a class="hashtag" href="http://test.discourse.org/category-hashtag">#<span>category-hashtag</span></a></p>',
    "it translates category hashtag into links"
  );

  assert.cooked(
    "Check out #category-hashtag",
    '<p>Check out <span class="hashtag">#category-hashtag</span></p>',
    "it does not translate category hashtag into links if it is not a valid category hashtag"
  );

  assert.cookedOptions(
    "[#category-hashtag](http://www.test.com)",
    alwaysTrue,
    '<p><a href="http://www.test.com">#category-hashtag</a></p>',
    "it does not translate category hashtag within links"
  );

  assert.cooked(
    "```\n# #category-hashtag\n```",
    '<pre><code class="lang-auto"># #category-hashtag\n</code></pre>',
    "it does not translate category hashtags to links in code blocks"
  );

  assert.cooked(
    "># #category-hashtag\n",
    '<blockquote>\n<h1><span class="hashtag">#category-hashtag</span></h1>\n</blockquote>',
    "it handles category hashtags in simple quotes"
  );

  assert.cooked(
    "# #category-hashtag",
    '<h1><span class="hashtag">#category-hashtag</span></h1>',
    "it works within ATX-style headers"
  );

  assert.cooked(
    "don't `#category-hashtag`",
    "<p>don't <code>#category-hashtag</code></p>",
    "it does not mention in an inline code block"
  );

  assert.cooked(
    "<small>#category-hashtag</small>",
    '<p><small><span class="hashtag">#category-hashtag</span></small></p>',
    "it works between HTML tags"
  );

  assert.cooked(
    "Checkout #ụdị",
    '<p>Checkout <span class="hashtag">#ụdị</span></p>',
    "it works for non-english characters"
  );
});

QUnit.test("Heading", assert => {
  assert.cooked(
    "**Bold**\n----------",
    "<h2><strong>Bold</strong></h2>",
    "It will bold the heading"
  );
});

QUnit.test("bold and italics", assert => {
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

QUnit.test("Escaping", assert => {
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

QUnit.test("New Lines", assert => {
  // historically we would not continue inline em or b across lines,
  // however commonmark gives us no switch to do so and we would be very non compliant.
  // turning softbreaks into a newline is just a renderer option, not a parser switch.
  assert.cooked(
    "_abc\ndef_",
    "<p><em>abc<br>\ndef</em></p>",
    "it does allow inlines to span new lines"
  );
  assert.cooked(
    "_abc\n\ndef_",
    "<p>_abc</p>\n<p>def_</p>",
    "it does not allow inlines to span new paragraphs"
  );
});

QUnit.test("Oneboxing", assert => {
  function matches(input, regexp) {
    return new PrettyText(defaultOpts).cook(input).match(regexp);
  }

  assert.ok(
    !matches(
      "- http://www.textfiles.com/bbs/MINDVOX/FORUMS/ethics\n\n- http://drupal.org",
      /class="onebox"/
    ),
    "doesn't onebox a link within a list"
  );

  assert.ok(
    matches("http://test.com", /class="onebox"/),
    "adds a onebox class to a link on its own line"
  );
  assert.ok(
    matches("http://test.com\nhttp://test2.com", /onebox[\s\S]+onebox/m),
    "supports multiple links"
  );
  assert.ok(
    !matches("http://test.com bob", /onebox/),
    "doesn't onebox links that have trailing text"
  );

  assert.ok(
    !matches("[Tom Cruise](http://www.tomcruise.com/)", "onebox"),
    "Markdown links with labels are not oneboxed"
  );
  assert.ok(
    !matches(
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

QUnit.test("links with full urls", assert => {
  assert.cooked(
    "[http://eviltrout.com][1] is a url\n\n[1]: http://eviltrout.com",
    '<p><a href="http://eviltrout.com">http://eviltrout.com</a> is a url</p>',
    "it supports links that are full URLs"
  );
});

QUnit.test("Code Blocks", assert => {
  assert.cooked(
    "<pre>\nhello\n</pre>\n",
    "<pre>\nhello\n</pre>",
    "pre blocks don't include extra lines"
  );

  assert.cooked(
    "```\na\nb\nc\n\nd\n```",
    '<pre><code class="lang-auto">a\nb\nc\n\nd\n</code></pre>',
    "it treats new lines properly"
  );

  assert.cooked(
    "```\ntest\n```",
    '<pre><code class="lang-auto">test\n</code></pre>',
    "it supports basic code blocks"
  );

  assert.cooked(
    "```json\n{hello: 'world'}\n```\ntrailing",
    "<pre><code class=\"lang-json\">{hello: 'world'}\n</code></pre>\n<p>trailing</p>",
    "It does not truncate text after a code block."
  );

  assert.cooked(
    "```json\nline 1\n\nline 2\n\n\nline3\n```",
    '<pre><code class="lang-json">line 1\n\nline 2\n\n\nline3\n</code></pre>',
    "it maintains new lines inside a code block."
  );

  assert.cooked(
    "hello\nworld\n```json\nline 1\n\nline 2\n\n\nline3\n```",
    '<p>hello<br>\nworld</p>\n<pre><code class="lang-json">line 1\n\nline 2\n\n\nline3\n</code></pre>',
    "it maintains new lines inside a code block with leading content."
  );

  assert.cooked(
    "```ruby\n<header>hello</header>\n```",
    '<pre><code class="lang-ruby">&lt;header&gt;hello&lt;/header&gt;\n</code></pre>',
    "it escapes code in the code block"
  );

  assert.cooked(
    "```text\ntext\n```",
    '<pre><code class="lang-nohighlight">text\n</code></pre>',
    "handles text by adding nohighlight"
  );

  assert.cooked(
    "```ruby\n# cool\n```",
    '<pre><code class="lang-ruby"># cool\n</code></pre>',
    "it supports changing the language"
  );

  assert.cooked(
    "    ```\n    hello\n    ```",
    "<pre><code>```\nhello\n```</code></pre>",
    "only detect ``` at the beginning of lines"
  );

  assert.cooked(
    "```ruby\ndef self.parse(text)\n\n  text\nend\n```",
    '<pre><code class="lang-ruby">def self.parse(text)\n\n  text\nend\n</code></pre>',
    "it allows leading spaces on lines in a code block."
  );

  assert.cooked(
    "```ruby\nhello `eviltrout`\n```",
    '<pre><code class="lang-ruby">hello `eviltrout`\n</code></pre>',
    "it allows code with backticks in it"
  );

  assert.cooked(
    "```eviltrout\nhello\n```",
    '<pre><code class="lang-auto">hello\n</code></pre>',
    "it doesn't not whitelist all classes"
  );

  assert.cooked(
    '```\n[quote="sam, post:1, topic:9441, full:true"]This is `<not>` a bug.[/quote]\n```',
    '<pre><code class="lang-auto">[quote=&quot;sam, post:1, topic:9441, full:true&quot;]This is `&lt;not&gt;` a bug.[/quote]\n</code></pre>',
    "it allows code with backticks in it"
  );

  assert.cooked(
    "    hello\n<blockquote>test</blockquote>",
    "<pre><code>hello\n</code></pre>\n<blockquote>test</blockquote>",
    "it allows an indented code block to by followed by a `<blockquote>`"
  );

  assert.cooked(
    "``` foo bar ```",
    "<p><code>foo bar</code></p>",
    "it tolerates misuse of code block tags as inline code"
  );

  assert.cooked(
    "```\nline1\n```\n```\nline2\n\nline3\n```",
    '<pre><code class="lang-auto">line1\n</code></pre>\n<pre><code class="lang-auto">line2\n\nline3\n</code></pre>',
    "it does not consume next block's trailing newlines"
  );

  assert.cooked(
    "    <pre>test</pre>",
    "<pre><code>&lt;pre&gt;test&lt;/pre&gt;</code></pre>",
    "it does not parse other block types in markdown code blocks"
  );

  assert.cooked(
    "    [quote]test[/quote]",
    "<pre><code>[quote]test[/quote]</code></pre>",
    "it does not parse other block types in markdown code blocks"
  );

  assert.cooked(
    "## a\nb\n```\nc\n```",
    '<h2>a</h2>\n<p>b</p>\n<pre><code class="lang-auto">c\n</code></pre>',
    "it handles headings with code blocks after them."
  );
});

QUnit.test("URLs in BBCode tags", assert => {
  assert.cooked(
    "[img]http://eviltrout.com/eviltrout.png[/img][img]http://samsaffron.com/samsaffron.png[/img]",
    '<p><img src="http://eviltrout.com/eviltrout.png" alt/><img src="http://samsaffron.com/samsaffron.png" alt/></p>',
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
});

QUnit.test("images", assert => {
  assert.cooked(
    "[![folksy logo](http://folksy.com/images/folksy-colour.png)](http://folksy.com/)",
    '<p><a href="http://folksy.com/"><img src="http://folksy.com/images/folksy-colour.png" alt="folksy logo"/></a></p>',
    "It allows images with links around them"
  );

  assert.cooked(
    '<img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot">',
    '<p><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot"></p>',
    "It allows data images"
  );
});

QUnit.test("censoring", assert => {
  assert.cooked(
    "aw shucks, golly gee whiz.",
    "<p>aw ■■■■■■, golly gee ■■■■.</p>",
    "it censors words in the Site Settings"
  );

  assert.cooked(
    "you are a whizzard! I love cheesewhiz. Whiz.",
    "<p>you are a whizzard! I love cheesewhiz. ■■■■.</p>",
    "it doesn't censor words unless they have boundaries."
  );

  assert.cooked(
    "you are a whizzer! I love cheesewhiz. Whiz.",
    "<p>you are a ■■■■■■■! I love cheesewhiz. ■■■■.</p>",
    "it censors words even if previous partial matches exist."
  );

  assert.cooked(
    "The link still works. [whiz](http://www.whiz.com)",
    '<p>The link still works. <a href="http://www.whiz.com">■■■■</a></p>',
    "it won't break links by censoring them."
  );

  assert.cooked(
    "Call techapj the computer whiz at 555-555-1234 for free help.",
    "<p>Call techapj the computer ■■■■ at 555-555-1234 for free help.</p>",
    "uses both censored words and patterns from site settings"
  );

  assert.cooked(
    "I have a pen, I have an a**le",
    "<p>I have a pen, I have an ■■■■■</p>",
    "it escapes regexp chars"
  );

  assert.cooked(
    "Aw shuck$, I can't fix the problem with money",
    "<p>Aw ■■■■■■, I can't fix the problem with money</p>",
    "it works for words ending in non-word characters"
  );

  assert.cooked(
    "Let's go to a café today",
    "<p>Let's go to a ■■■■ today</p>",
    "it works for words ending in accented characters"
  );

  assert.cooked(
    "Discourse is $uper amazing",
    "<p>Discourse is ■■■■■ amazing</p>",
    "it works for words starting with non-word characters"
  );

  assert.cooked(
    "No badword or apple here plz.",
    "<p>No ■■■■■■■ or ■■■■■ here plz.</p>",
    "it handles * as wildcard"
  );

  assert.cookedOptions(
    "Pleased to meet you, but pleeeease call me later, xyz123",
    {
      siteSettings: {
        watched_words_regular_expressions: true
      },
      censoredWords: "xyz*|plee+ase"
    },
    "<p>Pleased to meet you, but ■■■■ call me later, ■■■■123</p>",
    "supports words as regular expressions"
  );

  assert.cookedOptions(
    "Meet downtown in your town at the townhouse on Main St.",
    {
      siteSettings: {
        watched_words_regular_expressions: true
      },
      censoredWords: "\\btown\\b"
    },
    "<p>Meet downtown in your ■■■■ at the townhouse on Main St.</p>",
    "supports words as regular expressions"
  );
});

QUnit.test("code blocks/spans hoisting", assert => {
  assert.cooked(
    "```\n\n    some code\n```",
    '<pre><code class="lang-auto">\n    some code\n</code></pre>',
    "it works when nesting standard markdown code blocks within a fenced code block"
  );

  assert.cooked(
    "`$&`",
    "<p><code>$&amp;</code></p>",
    "it works even when hoisting special replacement patterns"
  );
});

QUnit.test("basic bbcode", assert => {
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
    '<img src="http://eviltrout.com/eviltrout.png" alt>',
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

QUnit.test("urls", assert => {
  assert.cookedPara(
    "[url]not a url[/url]",
    "not a url",
    "supports [url] that isn't a url"
  );
  assert.cookedPara(
    "[url]abc.com[/url]",
    '<a href="http://abc.com">abc.com</a>',
    "it magically links using linkify"
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
    '<a href="http://www.example.com" data-bbcode="true"><img src="http://example.com/logo.png" alt></a>',
    "supports [url] with an embedded [img]"
  );
});
QUnit.test("invalid bbcode", assert => {
  assert.cooked(
    "[code]I am not closed\n\nThis text exists.",
    "<p>[code]I am not closed</p>\n<p>This text exists.</p>",
    "does not raise an error with an open bbcode tag."
  );
});

QUnit.test("code", assert => {
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
    "it handles headings in a [code] block"
  );
  assert.cooked(
    "[code]\n   s\n[/code]",
    '<pre><code class="lang-auto">   s</code></pre>',
    "it doesn't trim leading whitespace"
  );
});

QUnit.test("tags with arguments", assert => {
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

QUnit.test("quotes", assert => {
  const post = Post.create({
    cooked: "<p><b>lorem</b> ipsum</p>",
    username: "eviltrout",
    post_number: 1,
    topic_id: 2
  });

  function formatQuote(val, expected, text) {
    assert.equal(Quote.build(post, val), expected, text);
  }

  formatQuote(undefined, "", "empty string for undefined content");
  formatQuote(null, "", "empty string for null content");
  formatQuote("", "", "empty string for empty string content");

  formatQuote(
    "lorem",
    '[quote="eviltrout, post:1, topic:2"]\nlorem\n[/quote]\n\n',
    "correctly formats quotes"
  );

  formatQuote(
    "  lorem \t  ",
    '[quote="eviltrout, post:1, topic:2"]\nlorem\n[/quote]\n\n',
    "trims white spaces before & after the quoted contents"
  );

  formatQuote(
    "lorem ipsum",
    '[quote="eviltrout, post:1, topic:2, full:true"]\nlorem ipsum\n[/quote]\n\n',
    "marks quotes as full when the quote is the full message"
  );

  formatQuote(
    "**lorem** ipsum",
    '[quote="eviltrout, post:1, topic:2, full:true"]\n**lorem** ipsum\n[/quote]\n\n',
    "keeps BBCode formatting"
  );

  assert.cooked(
    "[quote]\ntest\n[/quote]",
    '<aside class="quote no-group">\n<blockquote>\n<p>test</p>\n</blockquote>\n</aside>',
    "it supports quotes without params"
  );

  assert.cooked(
    "[quote]\n*test*\n[/quote]",
    '<aside class="quote no-group">\n<blockquote>\n<p><em>test</em></p>\n</blockquote>\n</aside>',
    "it doesn't insert a new line for italics"
  );

  assert.cooked(
    "[quote=,script='a'><script>alert('test');//':a]\n[/quote]",
    '<aside class="quote no-group">\n<blockquote></blockquote>\n</aside>',
    "It will not create a script tag within an attribute"
  );
});

QUnit.test("quote formatting", assert => {
  assert.cooked(
    '[quote="EvilTrout, post:123, topic:456, full:true"]\n[sam]\n[/quote]',
    `<aside class=\"quote no-group\" data-post=\"123\" data-topic=\"456\" data-full=\"true\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 EvilTrout:</div>
<blockquote>
<p>[sam]</p>
</blockquote>
</aside>`,
    "it allows quotes with [] inside"
  );

  assert.cooked(
    '[quote="eviltrout, post:1, topic:1"]\nabc\n[/quote]',
    `<aside class=\"quote no-group\" data-post=\"1\" data-topic=\"1\">
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
    `<aside class=\"quote no-group\" data-post=\"1\" data-topic=\"1\">
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
    `<aside class=\"quote no-group\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Alice:</div>
<blockquote>
<aside class=\"quote no-group\" data-post=\"2\" data-topic=\"1\">
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
<aside class=\"quote no-group\" data-post=\"2\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Bob:</div>
<blockquote></blockquote>
</aside>`,

    "handles mismatched nested quote tags (non greedy)"
  );

  assert.cooked(
    "[quote=\"Alice, post:1, topic:1\"]\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
    `<aside class=\"quote no-group\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Alice:</div>
<blockquote>
<pre><code class=\"lang-javascript\">var foo ='foo';
var bar = 'bar';
</code></pre>
</blockquote>
</aside>`,
    "quotes can have code blocks without leading newline"
  );

  assert.cooked(
    "[quote=\"Alice, post:1, topic:1\"]\n\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
    `<aside class=\"quote no-group\" data-post=\"1\" data-topic=\"1\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 Alice:</div>
<blockquote>
<pre><code class=\"lang-javascript\">var foo ='foo';
var bar = 'bar';
</code></pre>
</blockquote>
</aside>`,
    "quotes can have code blocks with leading newline"
  );
});

QUnit.test("quotes with trailing formatting", assert => {
  const result = new PrettyText(defaultOpts).cook(
    '[quote="EvilTrout, post:123, topic:456, full:true"]\nhello\n[/quote]\n*Test*'
  );
  assert.equal(
    result,
    `<aside class=\"quote no-group\" data-post=\"123\" data-topic=\"456\" data-full=\"true\">
<div class=\"title\">
<div class=\"quote-controls\"></div>
 EvilTrout:</div>
<blockquote>
<p>hello</p>
</blockquote>
</aside>
<p><em>Test</em></p>`,
    "it allows trailing formatting"
  );
});

QUnit.test("enable/disable features", assert => {
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

QUnit.test("emoji", assert => {
  assert.cooked(
    ":smile:",
    `<p><img src="/images/emoji/emoji_one/smile.png?v=${v}" title=":smile:" class="emoji" alt=":smile:"></p>`
  );
  assert.cooked(
    ":(",
    `<p><img src="/images/emoji/emoji_one/frowning.png?v=${v}" title=":frowning:" class="emoji" alt=":frowning:"></p>`
  );
  assert.cooked(
    "8-)",
    `<p><img src="/images/emoji/emoji_one/sunglasses.png?v=${v}" title=":sunglasses:" class="emoji" alt=":sunglasses:"></p>`
  );
});

QUnit.test("emoji - enable_inline_emoji_translation", assert => {
  assert.cookedOptions(
    "test:smile:test",
    { siteSettings: { enable_inline_emoji_translation: false } },
    `<p>test:smile:test</p>`
  );

  assert.cookedOptions(
    "test:smile:test",
    { siteSettings: { enable_inline_emoji_translation: true } },
    `<p>test<img src="/images/emoji/emoji_one/smile.png?v=${v}" title=":smile:" class="emoji" alt=":smile:">test</p>`
  );
});

QUnit.test("emoji - emojiSet", assert => {
  assert.cookedOptions(
    ":smile:",
    { siteSettings: { emoji_set: "twitter" } },
    `<p><img src="/images/emoji/twitter/smile.png?v=${v}" title=":smile:" class="emoji" alt=":smile:"></p>`
  );
});
