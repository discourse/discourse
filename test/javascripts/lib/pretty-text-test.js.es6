import Quote from 'discourse/lib/quote';
import Post from 'discourse/models/post';
import { default as PrettyText, buildOptions } from 'pretty-text/pretty-text';
import { IMAGE_VERSION as v} from 'pretty-text/emoji';

QUnit.module("lib:pretty-text");

const defaultOpts = buildOptions({
  siteSettings: {
    enable_emoji: true,
    emoji_set: 'emoji_one',
    highlighted_languages: 'json|ruby|javascript',
    default_code_lang: 'auto',
    censored_words: 'shucks|whiz|whizzer|a**le',
    censored_pattern: '\\d{3}-\\d{4}|tech\\w*'
  },
  getURL: url => url
});

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
  const actual = new PrettyText(_.merge({}, defaultOpts, opts)).cook(input);
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

QUnit.test("buildOptions", assert => {
  assert.ok(buildOptions({ siteSettings: { enable_emoji: true } }).features.emoji, 'emoji enabled');
  assert.ok(!buildOptions({ siteSettings: { enable_emoji: false } }).features.emoji, 'emoji disabled');
});

QUnit.test("basic cooking", assert => {
  assert.cooked("hello", "<p>hello</p>", "surrounds text with paragraphs");
  assert.cooked("**evil**", "<p><strong>evil</strong></p>", "it bolds text.");
  assert.cooked("__bold__", "<p><strong>bold</strong></p>", "it bolds text.");
  assert.cooked("*trout*", "<p><em>trout</em></p>", "it italicizes text.");
  assert.cooked("_trout_", "<p><em>trout</em></p>", "it italicizes text.");
  assert.cooked("***hello***", "<p><strong><em>hello</em></strong></p>", "it can do bold and italics at once.");
  assert.cooked("word_with_underscores", "<p>word_with_underscores</p>", "it doesn't do intraword italics");
  assert.cooked("common/_special_font_face.html.erb", "<p>common/_special_font_face.html.erb</p>", "it doesn't intraword with a slash");
  assert.cooked("hello \\*evil\\*", "<p>hello *evil*</p>", "it supports escaping of asterisks");
  assert.cooked("hello \\_evil\\_", "<p>hello _evil_</p>", "it supports escaping of italics");
  assert.cooked("brussels sprouts are *awful*.", "<p>brussels sprouts are <em>awful</em>.</p>", "it doesn't swallow periods.");
});

QUnit.test("Nested bold and italics", assert => {
  assert.cooked("*this is italic **with some bold** inside*", "<p><em>this is italic <strong>with some bold</strong> inside</em></p>", "it handles nested bold in italics");
});

QUnit.test("Traditional Line Breaks", assert => {
  const input = "1\n2\n3";
  assert.cooked(input, "<p>1<br/>2<br/>3</p>", "automatically handles trivial newlines");

  const result = new PrettyText({ traditionalMarkdownLinebreaks: true }).cook(input);
  assert.equal(result, "<p>1\n2\n3</p>");
});

QUnit.test("Unbalanced underscores", assert => {
  assert.cooked("[evil_trout][1] hello_\n\n[1]: http://eviltrout.com", "<p><a href=\"http://eviltrout.com\">evil_trout</a> hello_</p>");
});

QUnit.test("Line Breaks", assert => {
  assert.cooked("[] first choice\n[] second choice",
         "<p>[] first choice<br/>[] second choice</p>",
         "it handles new lines correctly with [] options");

  assert.cooked("<blockquote>evil</blockquote>\ntrout",
         "<blockquote>evil</blockquote>\n\n<p>trout</p>",
         "it doesn't insert <br> after blockquotes");

  assert.cooked("leading<blockquote>evil</blockquote>\ntrout",
         "leading<blockquote>evil</blockquote>\n\n<p>trout</p>",
         "it doesn't insert <br> after blockquotes with leading text");
});

QUnit.test("Paragraphs for HTML", assert => {
  assert.cooked("<div>hello world</div>", "<div>hello world</div>", "it doesn't surround <div> with paragraphs");
  assert.cooked("<p>hello world</p>", "<p>hello world</p>", "it doesn't surround <p> with paragraphs");
  assert.cooked("<i>hello world</i>", "<p><i>hello world</i></p>", "it surrounds inline <i> html tags with paragraphs");
  assert.cooked("<b>hello world</b>", "<p><b>hello world</b></p>", "it surrounds inline <b> html tags with paragraphs");
});

QUnit.test("Links", assert => {

  assert.cooked("EvilTrout: http://eviltrout.com",
         '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a></p>',
         "autolinks a URL");

  assert.cooked("Youtube: http://www.youtube.com/watch?v=1MrpeBRkM5A",
         '<p>Youtube: <a href="http://www.youtube.com/watch?v=1MrpeBRkM5A">http://www.youtube.com/watch?v=1MrpeBRkM5A</a></p>',
         "allows links to contain query params");

  assert.cooked("Derpy: http://derp.com?__test=1",
         '<p>Derpy: <a href="http://derp.com?__test=1">http://derp.com?__test=1</a></p>',
         "works with double underscores in urls");

  assert.cooked("Derpy: http://derp.com?_test_=1",
         '<p>Derpy: <a href="http://derp.com?_test_=1">http://derp.com?_test_=1</a></p>',
         "works with underscores in urls");

  assert.cooked("Atwood: www.codinghorror.com",
         '<p>Atwood: <a href="http://www.codinghorror.com">www.codinghorror.com</a></p>',
         "autolinks something that begins with www");

  assert.cooked("Atwood: http://www.codinghorror.com",
         '<p>Atwood: <a href="http://www.codinghorror.com">http://www.codinghorror.com</a></p>',
         "autolinks a URL with http://www");

  assert.cooked("EvilTrout: http://eviltrout.com hello",
         '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a> hello</p>',
         "autolinks with trailing text");

  assert.cooked("here is [an example](http://twitter.com)",
         '<p>here is <a href="http://twitter.com">an example</a></p>',
         "supports markdown style links");

  assert.cooked("Batman: http://en.wikipedia.org/wiki/The_Dark_Knight_(film)",
         '<p>Batman: <a href="http://en.wikipedia.org/wiki/The_Dark_Knight_(film)">http://en.wikipedia.org/wiki/The_Dark_Knight_(film)</a></p>',
         "autolinks a URL with parentheses (like Wikipedia)");

  assert.cooked("Here's a tweet:\nhttps://twitter.com/evil_trout/status/345954894420787200",
         "<p>Here's a tweet:<br/><a href=\"https://twitter.com/evil_trout/status/345954894420787200\" class=\"onebox\" target=\"_blank\">https://twitter.com/evil_trout/status/345954894420787200</a></p>",
         "It doesn't strip the new line.");

  assert.cooked("1. View @eviltrout's profile here: http://meta.discourse.org/u/eviltrout/activity<br/>next line.",
        "<ol><li>View <span class=\"mention\">@eviltrout</span>'s profile here: <a href=\"http://meta.discourse.org/u/eviltrout/activity\">http://meta.discourse.org/u/eviltrout/activity</a><br>next line.</li></ol>",
        "allows autolinking within a list without inserting a paragraph.");

  assert.cooked("[3]: http://eviltrout.com", "", "It doesn't autolink markdown link references");

  assert.cooked("[]: http://eviltrout.com", "<p>[]: <a href=\"http://eviltrout.com\">http://eviltrout.com</a></p>", "It doesn't accept empty link references");

  assert.cooked("[b]label[/b]: description", "<p><span class=\"bbcode-b\">label</span>: description</p>", "It doesn't accept BBCode as link references");

  assert.cooked("http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369",
         "<p><a href=\"http://discourse.org\">http://discourse.org</a> and " +
         "<a href=\"http://discourse.org/another_url\">http://discourse.org/another_url</a> and " +
         "<a href=\"http://www.imdb.com/name/nm2225369\">http://www.imdb.com/name/nm2225369</a></p>",
         'allows multiple links on one line');

  assert.cooked("* [Evil Trout][1]\n  [1]: http://eviltrout.com",
         "<ul><li><a href=\"http://eviltrout.com\">Evil Trout</a></li></ul>",
         "allows markdown link references in a list");

  assert.cooked("User [MOD]: Hello!",
         "<p>User [MOD]: Hello!</p>",
         "It does not consider references that are obviously not URLs");

  assert.cooked("<small>http://eviltrout.com</small>", "<p><small><a href=\"http://eviltrout.com\">http://eviltrout.com</a></small></p>", "Links within HTML tags");

  assert.cooked("[http://google.com ... wat](http://discourse.org)",
         "<p><a href=\"http://discourse.org\">http://google.com ... wat</a></p>",
         "it supports links within links");

  assert.cooked("[http://google.com](http://discourse.org)",
         "<p><a href=\"http://discourse.org\">http://google.com</a></p>",
         "it supports markdown links where the name and link match");


  assert.cooked("[Link](http://www.example.com) (with an outer \"description\")",
         "<p><a href=\"http://www.example.com\">Link</a> (with an outer \"description\")</p>",
         "it doesn't consume closing parens as part of the url");

  assert.cooked("A link inside parentheses (http://www.example.com)",
         "<p>A link inside parentheses (<a href=\"http://www.example.com\">http://www.example.com</a>)</p>",
         "it auto-links a url within parentheses");

  assert.cooked("[ul][1]\n\n[1]: http://eviltrout.com",
         "<p><a href=\"http://eviltrout.com\">ul</a></p>",
         "it can use `ul` as a link name");
});

QUnit.test("simple quotes", assert => {
  assert.cooked("> nice!", "<blockquote><p>nice!</p></blockquote>", "it supports simple quotes");
  assert.cooked(" > nice!", "<blockquote><p>nice!</p></blockquote>", "it allows quotes with preceding spaces");
  assert.cooked("> level 1\n> > level 2",
         "<blockquote><p>level 1</p><blockquote><p>level 2</p></blockquote></blockquote>",
         "it allows nesting of blockquotes");
  assert.cooked("> level 1\n>  > level 2",
         "<blockquote><p>level 1</p><blockquote><p>level 2</p></blockquote></blockquote>",
         "it allows nesting of blockquotes with spaces");

  assert.cooked("- hello\n\n  > world\n  > eviltrout",
         "<ul><li>hello</li></ul>\n\n<blockquote><p>world<br/>eviltrout</p></blockquote>",
         "it allows quotes within a list.");

  assert.cooked("- <p>eviltrout</p>",
         "<ul><li><p>eviltrout</p></li></ul>",
         "it allows paragraphs within a list.");


  assert.cooked("  > indent 1\n  > indent 2", "<blockquote><p>indent 1<br/>indent 2</p></blockquote>", "allow multiple spaces to indent");

});

QUnit.test("Quotes", assert => {

  assert.cookedOptions("[quote=\"eviltrout, post: 1\"]\na quote\n\nsecond line\n\nthird line[/quote]",
                { topicId: 2 },
                "<aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout:</div><blockquote>" +
                "<p>a quote</p><p>second line</p><p>third line</p></blockquote></aside>",
                "works with multiple lines");

  assert.cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function(name) { return "" + name; }, sanitize: true },
                "<p>1</p>\n\n<aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>bob" +
                "bob:</div><blockquote><p>my quote</p></blockquote></aside>\n\n<p>2</p>",
                "handles quotes properly");

  assert.cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function() { } },
                "<p>1</p>\n\n<aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>bob:" +
                "</div><blockquote><p>my quote</p></blockquote></aside>\n\n<p>2</p>",
                "includes no avatar if none is found");

  assert.cooked(`[quote]\na\n\n[quote]\nb\n[/quote]\n[/quote]`,
         "<p><aside class=\"quote\"><blockquote><p>a</p><p><aside class=\"quote\"><blockquote><p>b</p></blockquote></aside></p></blockquote></aside></p>",
         "handles nested quotes properly");

});

QUnit.test("Mentions", assert => {

  const alwaysTrue = { mentionLookup: (function() { return "user"; }) };

  assert.cookedOptions("Hello @sam", alwaysTrue,
                "<p>Hello <a class=\"mention\" href=\"/u/sam\">@sam</a></p>",
                "translates mentions to links");

  assert.cooked("[@codinghorror](https://twitter.com/codinghorror)",
         "<p><a href=\"https://twitter.com/codinghorror\">@codinghorror</a></p>",
         "it doesn't do mentions within links");

  assert.cookedOptions("[@codinghorror](https://twitter.com/codinghorror)", alwaysTrue,
         "<p><a href=\"https://twitter.com/codinghorror\">@codinghorror</a></p>",
         "it doesn't do link mentions within links");

  assert.cooked("Hello @EvilTrout",
         "<p>Hello <span class=\"mention\">@EvilTrout</span></p>",
         "adds a mention class");

  assert.cooked("robin@email.host",
         "<p>robin@email.host</p>",
         "won't add mention class to an email address");

  assert.cooked("hanzo55@yahoo.com",
         "<p>hanzo55@yahoo.com</p>",
         "won't be affected by email addresses that have a number before the @ symbol");

  assert.cooked("@EvilTrout yo",
         "<p><span class=\"mention\">@EvilTrout</span> yo</p>",
         "it handles mentions at the beginning of a string");

  assert.cooked("yo\n@EvilTrout",
         "<p>yo<br/><span class=\"mention\">@EvilTrout</span></p>",
         "it handles mentions at the beginning of a new line");

  assert.cooked("`evil` @EvilTrout `trout`",
         "<p><code>evil</code> <span class=\"mention\">@EvilTrout</span> <code>trout</code></p>",
         "deals correctly with multiple <code> blocks");

  assert.cooked("```\na @test\n```",
         "<p><pre><code class=\"lang-auto\">a @test</code></pre></p>",
         "should not do mentions within a code block.");

  assert.cooked("> foo bar baz @eviltrout",
         "<blockquote><p>foo bar baz <span class=\"mention\">@eviltrout</span></p></blockquote>",
         "handles mentions in simple quotes");

  assert.cooked("> foo bar baz @eviltrout ohmagerd\nlook at this",
         "<blockquote><p>foo bar baz <span class=\"mention\">@eviltrout</span> ohmagerd<br/>look at this</p></blockquote>",
         "does mentions properly with trailing text within a simple quote");

  assert.cooked("`code` is okay before @mention",
         "<p><code>code</code> is okay before <span class=\"mention\">@mention</span></p>",
         "Does not mention in an inline code block");

  assert.cooked("@mention is okay before `code`",
         "<p><span class=\"mention\">@mention</span> is okay before <code>code</code></p>",
         "Does not mention in an inline code block");

  assert.cooked("don't `@mention`",
         "<p>don't <code>@mention</code></p>",
         "Does not mention in an inline code block");

  assert.cooked("Yes `@this` should be code @eviltrout",
         "<p>Yes <code>@this</code> should be code <span class=\"mention\">@eviltrout</span></p>",
         "Does not mention in an inline code block");

  assert.cooked("@eviltrout and `@eviltrout`",
         "<p><span class=\"mention\">@eviltrout</span> and <code>@eviltrout</code></p>",
         "you can have a mention in an inline code block following a real mention.");

  assert.cooked("1. this is  a list\n\n2. this is an @eviltrout mention\n",
         "<ol><li><p>this is  a list</p></li><li><p>this is an <span class=\"mention\">@eviltrout</span> mention</p></li></ol>",
         "it mentions properly in a list.");

  assert.cooked("Hello @foo/@bar",
         "<p>Hello <span class=\"mention\">@foo</span>/<span class=\"mention\">@bar</span></p>",
         "handles mentions separated by a slash.");

  assert.cookedOptions("@eviltrout", alwaysTrue,
                "<p><a class=\"mention\" href=\"/u/eviltrout\">@eviltrout</a></p>",
                "it doesn't onebox mentions");

  assert.cookedOptions("<small>a @sam c</small>", alwaysTrue,
                "<p><small>a <a class=\"mention\" href=\"/u/sam\">@sam</a> c</small></p>",
                "it allows mentions within HTML tags");
});

QUnit.test("Category hashtags", assert => {
  const alwaysTrue = { categoryHashtagLookup: (function() { return ["http://test.discourse.org/category-hashtag", "category-hashtag"]; }) };

  assert.cookedOptions("Check out #category-hashtag", alwaysTrue,
         "<p>Check out <a class=\"hashtag\" href=\"http://test.discourse.org/category-hashtag\">#<span>category-hashtag</span></a></p>",
         "it translates category hashtag into links");

  assert.cooked("Check out #category-hashtag",
         "<p>Check out <span class=\"hashtag\">#category-hashtag</span></p>",
         "it does not translate category hashtag into links if it is not a valid category hashtag");

  assert.cookedOptions("[#category-hashtag](http://www.test.com)", alwaysTrue,
         "<p><a href=\"http://www.test.com\">#category-hashtag</a></p>",
         "it does not translate category hashtag within links");

  assert.cooked("```\n# #category-hashtag\n```",
         "<p><pre><code class=\"lang-auto\"># #category-hashtag</code></pre></p>",
         "it does not translate category hashtags to links in code blocks");

  assert.cooked("># #category-hashtag\n",
         "<blockquote><h1><span class=\"hashtag\">#category-hashtag</span></h1></blockquote>",
         "it handles category hashtags in simple quotes");

  assert.cooked("# #category-hashtag",
         "<h1><span class=\"hashtag\">#category-hashtag</span></h1>",
         "it works within ATX-style headers");

  assert.cooked("don't `#category-hashtag`",
         "<p>don't <code>#category-hashtag</code></p>",
         "it does not mention in an inline code block");

  assert.cooked("test #hashtag1/#hashtag2",
         "<p>test <span class=\"hashtag\">#hashtag1</span>/#hashtag2</p>",
         "it does not convert category hashtag not bounded by spaces");

  assert.cooked("<small>#category-hashtag</small>",
         "<p><small><span class=\"hashtag\">#category-hashtag</span></small></p>",
         "it works between HTML tags");
});


QUnit.test("Heading", assert => {
  assert.cooked("**Bold**\n----------", "<h2><strong>Bold</strong></h2>", "It will bold the heading");
});

QUnit.test("bold and italics", assert => {
  assert.cooked("a \"**hello**\"", "<p>a \"<strong>hello</strong>\"</p>", "bolds in quotes");
  assert.cooked("(**hello**)", "<p>(<strong>hello</strong>)</p>", "bolds in parens");
  assert.cooked("**hello**\nworld", "<p><strong>hello</strong><br>world</p>", "allows newline after bold");
  assert.cooked("**hello**\n**world**", "<p><strong>hello</strong><br><strong>world</strong></p>", "newline between two bolds");
  assert.cooked("**a*_b**", "<p><strong>a*_b</strong></p>", "allows for characters within bold");
  assert.cooked("** hello**", "<p>** hello**</p>", "does not bold on a space boundary");
  assert.cooked("**hello **", "<p>**hello **</p>", "does not bold on a space boundary");
  assert.cooked("你**hello**", "<p>你**hello**</p>", "does not bold chinese intra word");
  assert.cooked("**你hello**", "<p><strong>你hello</strong></p>", "allows bolded chinese");
});

QUnit.test("Escaping", assert => {
  assert.cooked("*\\*laughs\\**", "<p><em>*laughs*</em></p>", "allows escaping strong");
  assert.cooked("*\\_laughs\\_*", "<p><em>_laughs_</em></p>", "allows escaping em");
});

QUnit.test("New Lines", assert => {
  // Note: This behavior was discussed and we determined it does not make sense to do this
  // unless you're using traditional line breaks
  assert.cooked("_abc\ndef_", "<p>_abc<br>def_</p>", "it does not allow markup to span new lines");
  assert.cooked("_abc\n\ndef_", "<p>_abc</p>\n\n<p>def_</p>", "it does not allow markup to span new paragraphs");
});

QUnit.test("Oneboxing", assert => {

  function matches(input, regexp) {
    return new PrettyText(defaultOpts).cook(input).match(regexp);
  };

  assert.ok(!matches("- http://www.textfiles.com/bbs/MINDVOX/FORUMS/ethics\n\n- http://drupal.org", /onebox/),
              "doesn't onebox a link within a list");

  assert.ok(matches("http://test.com", /onebox/), "adds a onebox class to a link on its own line");
  assert.ok(matches("http://test.com\nhttp://test2.com", /onebox[\s\S]+onebox/m), "supports multiple links");
  assert.ok(!matches("http://test.com bob", /onebox/), "doesn't onebox links that have trailing text");

  assert.ok(!matches("[Tom Cruise](http://www.tomcruise.com/)", "onebox"), "Markdown links with labels are not oneboxed");
  assert.ok(matches("[http://www.tomcruise.com/](http://www.tomcruise.com/)",
    "onebox"),
    "Markdown links where the label is the same as the url are oneboxed");

  assert.cooked("http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street",
         "<p><a href=\"http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street\" class=\"onebox\"" +
         " target=\"_blank\">http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street</a></p>",
         "works with links that have underscores in them");

});

QUnit.test("links with full urls", assert => {
  assert.cooked("[http://eviltrout.com][1] is a url\n\n[1]: http://eviltrout.com",
         "<p><a href=\"http://eviltrout.com\">http://eviltrout.com</a> is a url</p>",
         "it supports links that are full URLs");
});

QUnit.test("Code Blocks", assert => {

  assert.cooked("<pre>\nhello\n</pre>\n",
         "<p><pre>hello</pre></p>",
         "pre blocks don't include extra lines");

  assert.cooked("```\na\nb\nc\n\nd\n```",
         "<p><pre><code class=\"lang-auto\">a\nb\nc\n\nd</code></pre></p>",
         "it treats new lines properly");

  assert.cooked("```\ntest\n```",
         "<p><pre><code class=\"lang-auto\">test</code></pre></p>",
         "it supports basic code blocks");

  assert.cooked("```json\n{hello: 'world'}\n```\ntrailing",
         "<p><pre><code class=\"lang-json\">{hello: &#x27;world&#x27;}</code></pre></p>\n\n<p>trailing</p>",
         "It does not truncate text after a code block.");

  assert.cooked("```json\nline 1\n\nline 2\n\n\nline3\n```",
         "<p><pre><code class=\"lang-json\">line 1\n\nline 2\n\n\nline3</code></pre></p>",
         "it maintains new lines inside a code block.");

  assert.cooked("hello\nworld\n```json\nline 1\n\nline 2\n\n\nline3\n```",
         "<p>hello<br/>world<br/></p>\n\n<p><pre><code class=\"lang-json\">line 1\n\nline 2\n\n\nline3</code></pre></p>",
         "it maintains new lines inside a code block with leading content.");

  assert.cooked("```ruby\n<header>hello</header>\n```",
         "<p><pre><code class=\"lang-ruby\">&lt;header&gt;hello&lt;/header&gt;</code></pre></p>",
         "it escapes code in the code block");

  assert.cooked("```text\ntext\n```",
         "<p><pre><code class=\"lang-nohighlight\">text</code></pre></p>",
         "handles text by adding nohighlight");

  assert.cooked("```ruby\n# cool\n```",
         "<p><pre><code class=\"lang-ruby\"># cool</code></pre></p>",
         "it supports changing the language");

  assert.cooked("    ```\n    hello\n    ```",
         "<pre><code>&#x60;&#x60;&#x60;\nhello\n&#x60;&#x60;&#x60;</code></pre>",
         "only detect ``` at the beginning of lines");

  assert.cooked("```ruby\ndef self.parse(text)\n\n  text\nend\n```",
         "<p><pre><code class=\"lang-ruby\">def self.parse(text)\n\n  text\nend</code></pre></p>",
         "it allows leading spaces on lines in a code block.");

  assert.cooked("```ruby\nhello `eviltrout`\n```",
         "<p><pre><code class=\"lang-ruby\">hello &#x60;eviltrout&#x60;</code></pre></p>",
         "it allows code with backticks in it");

  assert.cooked("```eviltrout\nhello\n```",
          "<p><pre><code class=\"lang-auto\">hello</code></pre></p>",
          "it doesn't not whitelist all classes");

  assert.cooked("```\n[quote=\"sam, post:1, topic:9441, full:true\"]This is `<not>` a bug.[/quote]\n```",
         "<p><pre><code class=\"lang-auto\">[quote=&quot;sam, post:1, topic:9441, full:true&quot;]This is &#x60;&lt;not&gt;&#x60; a bug.[/quote]</code></pre></p>",
         "it allows code with backticks in it");

  assert.cooked("    hello\n<blockquote>test</blockquote>",
         "<pre><code>hello</code></pre>\n\n<blockquote>test</blockquote>",
         "it allows an indented code block to by followed by a `<blockquote>`");

  assert.cooked("``` foo bar ```",
         "<p><code>foo bar</code></p>",
         "it tolerates misuse of code block tags as inline code");

  assert.cooked("```\nline1\n```\n```\nline2\n\nline3\n```",
         "<p><pre><code class=\"lang-auto\">line1</code></pre></p>\n\n<p><pre><code class=\"lang-auto\">line2\n\nline3</code></pre></p>",
         "it does not consume next block's trailing newlines");

  assert.cooked("    <pre>test</pre>",
         "<pre><code>&lt;pre&gt;test&lt;/pre&gt;</code></pre>",
         "it does not parse other block types in markdown code blocks");

  assert.cooked("    [quote]test[/quote]",
         "<pre><code>[quote]test[/quote]</code></pre>",
         "it does not parse other block types in markdown code blocks");

  assert.cooked("## a\nb\n```\nc\n```",
         "<h2>a</h2>\n\n<p><pre><code class=\"lang-auto\">c</code></pre></p>",
         "it handles headings with code blocks after them.");
});

QUnit.test("URLs in BBCode tags", assert => {

  assert.cooked("[img]http://eviltrout.com/eviltrout.png[/img][img]http://samsaffron.com/samsaffron.png[/img]",
         "<p><img src=\"http://eviltrout.com/eviltrout.png\"/><img src=\"http://samsaffron.com/samsaffron.png\"/></p>",
         "images are properly parsed");

  assert.cooked("[url]http://discourse.org[/url]",
         "<p><a href=\"http://discourse.org\">http://discourse.org</a></p>",
         "links are properly parsed");

  assert.cooked("[url=http://discourse.org]discourse[/url]",
         "<p><a href=\"http://discourse.org\">discourse</a></p>",
         "named links are properly parsed");

});

QUnit.test("images", assert => {
  assert.cooked("[![folksy logo](http://folksy.com/images/folksy-colour.png)](http://folksy.com/)",
         "<p><a href=\"http://folksy.com/\"><img src=\"http://folksy.com/images/folksy-colour.png\" alt=\"folksy logo\"/></a></p>",
         "It allows images with links around them");

  assert.cooked("<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\">",
         "<p><img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\"></p>",
         "It allows data images");
});

QUnit.test("censoring", assert => {
  assert.cooked("aw shucks, golly gee whiz.",
         "<p>aw &#9632;&#9632;&#9632;&#9632;&#9632;&#9632;, golly gee &#9632;&#9632;&#9632;&#9632;.</p>",
         "it censors words in the Site Settings");

  assert.cooked("you are a whizzard! I love cheesewhiz. Whiz.",
         "<p>you are a whizzard! I love cheesewhiz. &#9632;&#9632;&#9632;&#9632;.</p>",
         "it doesn't censor words unless they have boundaries.");

  assert.cooked("you are a whizzer! I love cheesewhiz. Whiz.",
         "<p>you are a &#9632;&#9632;&#9632;&#9632;&#9632;&#9632;&#9632;! I love cheesewhiz. &#9632;&#9632;&#9632;&#9632;.</p>",
         "it censors words even if previous partial matches exist.");

  assert.cooked("The link still works. [whiz](http://www.whiz.com)",
         "<p>The link still works. <a href=\"http://www.whiz.com\">&#9632;&#9632;&#9632;&#9632;</a></p>",
         "it won't break links by censoring them.");

  assert.cooked("Call techapj the computer whiz at 555-555-1234 for free help.",
         "<p>Call &#9632;&#9632;&#9632;&#9632;&#9632;&#9632;&#9632; the computer &#9632;&#9632;&#9632;&#9632; at 555-&#9632;&#9632;&#9632;&#9632;&#9632;&#9632;&#9632;&#9632; for free help.</p>",
         "uses both censored words and patterns from site settings");

  assert.cooked("I have a pen, I have an a**le",
         "<p>I have a pen, I have an &#9632;&#9632;&#9632;&#9632;&#9632;</p>",
         "it escapes regexp chars");
});

QUnit.test("code blocks/spans hoisting", assert => {
  assert.cooked("```\n\n    some code\n```",
         "<p><pre><code class=\"lang-auto\">    some code</code></pre></p>",
         "it works when nesting standard markdown code blocks within a fenced code block");

  assert.cooked("`$&`",
         "<p><code>$&amp;</code></p>",
         "it works even when hoisting special replacement patterns");
});

QUnit.test('basic bbcode', assert => {
  assert.cookedPara("[b]strong[/b]", "<span class=\"bbcode-b\">strong</span>", "bolds text");
  assert.cookedPara("[i]emphasis[/i]", "<span class=\"bbcode-i\">emphasis</span>", "italics text");
  assert.cookedPara("[u]underlined[/u]", "<span class=\"bbcode-u\">underlined</span>", "underlines text");
  assert.cookedPara("[s]strikethrough[/s]", "<span class=\"bbcode-s\">strikethrough</span>", "strikes-through text");
  assert.cookedPara("[img]http://eviltrout.com/eviltrout.png[/img]", "<img src=\"http://eviltrout.com/eviltrout.png\">", "links images");
  assert.cookedPara("[email]eviltrout@mailinator.com[/email]", "<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>", "supports [email] without a title");
  assert.cookedPara("[b]evil [i]trout[/i][/b]",
         "<span class=\"bbcode-b\">evil <span class=\"bbcode-i\">trout</span></span>",
         "allows embedding of tags");
  assert.cookedPara("[EMAIL]eviltrout@mailinator.com[/EMAIL]", "<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>", "supports upper case bbcode");
  assert.cookedPara("[b]strong [b]stronger[/b][/b]", "<span class=\"bbcode-b\">strong <span class=\"bbcode-b\">stronger</span></span>", "accepts nested bbcode tags");
});

QUnit.test('urls', assert => {
  assert.cookedPara("[url]not a url[/url]", "not a url", "supports [url] that isn't a url");
  assert.cookedPara("[url]abc.com[/url]", "abc.com", "no error when a url has no protocol and begins with a");
  assert.cookedPara("[url]http://bettercallsaul.com[/url]", "<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>", "supports [url] without parameter");
  assert.cookedPara("[url=http://example.com]example[/url]", "<a href=\"http://example.com\">example</a>", "supports [url] with given href");
  assert.cookedPara("[url=http://www.example.com][img]http://example.com/logo.png[/img][/url]",
         "<a href=\"http://www.example.com\"><img src=\"http://example.com/logo.png\"></a>",
         "supports [url] with an embedded [img]");
});
QUnit.test('invalid bbcode', assert => {
  const result = new PrettyText({ lookupAvatar: false }).cook("[code]I am not closed\n\nThis text exists.");
  assert.equal(result, "<p>[code]I am not closed</p>\n\n<p>This text exists.</p>", "does not raise an error with an open bbcode tag.");
});

QUnit.test('code', assert => {
  assert.cookedPara("[code]\nx++\n[/code]", "<pre><code class=\"lang-auto\">x++</code></pre>", "makes code into pre");
  assert.cookedPara("[code]\nx++\ny++\nz++\n[/code]", "<pre><code class=\"lang-auto\">x++\ny++\nz++</code></pre>", "makes code into pre");
  assert.cookedPara("[code]abc\n#def\n[/code]", '<pre><code class=\"lang-auto\">abc\n#def</code></pre>', 'it handles headings in a [code] block');
  assert.cookedPara("[code]\n   s[/code]",
         "<pre><code class=\"lang-auto\">   s</code></pre>",
         "it doesn't trim leading whitespace");
});

QUnit.test('lists', assert => {
  assert.cookedPara("[ul][li]option one[/li][/ul]", "<ul><li>option one</li></ul>", "creates an ul");
  assert.cookedPara("[ol][li]option one[/li][/ol]", "<ol><li>option one</li></ol>", "creates an ol");
  assert.cookedPara("[ul]\n[li]option one[/li]\n[li]option two[/li]\n[/ul]", "<ul><li>option one</li><li>option two</li></ul>", "suppresses empty lines in lists");
});

QUnit.test('tags with arguments', assert => {
  assert.cookedPara("[url=http://bettercallsaul.com]better call![/url]", "<a href=\"http://bettercallsaul.com\">better call!</a>", "supports [url] with a title");
  assert.cookedPara("[email=eviltrout@mailinator.com]evil trout[/email]", "<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>", "supports [email] with a title");
  assert.cookedPara("[u][i]abc[/i][/u]", "<span class=\"bbcode-u\"><span class=\"bbcode-i\">abc</span></span>", "can nest tags");
  assert.cookedPara("[b]first[/b] [b]second[/b]", "<span class=\"bbcode-b\">first</span> <span class=\"bbcode-b\">second</span>", "can bold two things on the same line");
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
  };

  formatQuote(undefined, "", "empty string for undefined content");
  formatQuote(null, "", "empty string for null content");
  formatQuote("", "", "empty string for empty string content");

  formatQuote("lorem", "[quote=\"eviltrout, post:1, topic:2\"]\nlorem\n[/quote]\n\n", "correctly formats quotes");

  formatQuote("  lorem \t  ",
              "[quote=\"eviltrout, post:1, topic:2\"]\nlorem\n[/quote]\n\n",
              "trims white spaces before & after the quoted contents");

  formatQuote("lorem ipsum",
              "[quote=\"eviltrout, post:1, topic:2, full:true\"]\nlorem ipsum\n[/quote]\n\n",
              "marks quotes as full when the quote is the full message");

  formatQuote("**lorem** ipsum",
              "[quote=\"eviltrout, post:1, topic:2, full:true\"]\n**lorem** ipsum\n[/quote]\n\n",
               "keeps BBCode formatting");

  formatQuote("this is <not> a bug",
              "[quote=\"eviltrout, post:1, topic:2\"]\nthis is &lt;not&gt; a bug\n[/quote]\n\n",
              "it escapes the contents of the quote");

  assert.cookedPara("[quote]test[/quote]",
         "<aside class=\"quote\"><blockquote><p>test</p></blockquote></aside>",
         "it supports quotes without params");

  assert.cookedPara("[quote]\n*test*\n[/quote]",
         "<aside class=\"quote\"><blockquote><p><em>test</em></p></blockquote></aside>",
         "it doesn't insert a new line for italics");

  assert.cookedPara("[quote=,script='a'><script>alert('test');//':a][/quote]",
         "<aside class=\"quote\"><blockquote></blockquote></aside>",
         "It will not create a script tag within an attribute");
});

QUnit.test("quote formatting", assert => {

  assert.cooked("[quote=\"EvilTrout, post:123, topic:456, full:true\"][sam][/quote]",
          "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">" +
          "<div class=\"quote-controls\"></div>EvilTrout:</div><blockquote><p>[sam]</p></blockquote></aside>",
          "it allows quotes with [] inside");

  assert.cooked("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout:" +
         "</div><blockquote><p>abc</p></blockquote></aside>",
         "renders quotes properly");

  assert.cooked("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]\nhello",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout:" +
         "</div><blockquote><p>abc</p></blockquote></aside>\n\n<p>hello</p>",
         "handles new lines properly");

  assert.cooked("[quote=\"Alice, post:1, topic:1\"]\n[quote=\"Bob, post:2, topic:1\"]\n[/quote]\n[/quote]",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:" +
         "</div><blockquote><aside class=\"quote\" data-post=\"2\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Bob:" +
         "</div><blockquote></blockquote></aside></blockquote></aside>",
         "quotes can be nested");

  assert.cooked("[quote=\"Alice, post:1, topic:1\"]\n[quote=\"Bob, post:2, topic:1\"]\n[/quote]",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:" +
         "</div><blockquote><p>[quote=\"Bob, post:2, topic:1\"]</p></blockquote></aside>",
         "handles mismatched nested quote tags");

  assert.cooked("[quote=\"Alice, post:1, topic:1\"]\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
          "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:</div><blockquote><p><pre><code class=\"lang-javascript\">var foo =&#x27;foo&#x27;;\nvar bar = &#x27;bar&#x27;;</code></pre></p></blockquote></aside>",
          "quotes can have code blocks without leading newline");
  assert.cooked("[quote=\"Alice, post:1, topic:1\"]\n\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
          "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:</div><blockquote><p><pre><code class=\"lang-javascript\">var foo =&#x27;foo&#x27;;\nvar bar = &#x27;bar&#x27;;</code></pre></p></blockquote></aside>",
          "quotes can have code blocks with leading newline");
});

QUnit.test("quotes with trailing formatting", assert => {
  const result = new PrettyText(defaultOpts).cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]\nhello\n[/quote]\n*Test*");
  assert.equal(result,
        "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">" +
        "<div class=\"quote-controls\"></div>EvilTrout:</div><blockquote><p>hello</p></blockquote></aside>\n\n<p><em>Test</em></p>",
        "it allows trailing formatting");
});

QUnit.test("enable/disable features", assert => {
  const table = `<table><tr><th>hello</th></tr><tr><td>world</td></tr></table>`;
  const hasTable = new PrettyText({ features: {table: true}, sanitize: true}).cook(table);
  assert.equal(hasTable, `<table class="md-table"><tr><th>hello</th></tr><tr><td>world</td></tr></table>`);

  const noTable = new PrettyText({ features: { table: false }, sanitize: true}).cook(table);
  assert.equal(noTable, `<p></p>`, 'tables are stripped when disabled');
});

QUnit.test("emoji", assert => {
  assert.cooked(":smile:", `<p><img src="/images/emoji/emoji_one/smile.png?v=${v}" title=":smile:" class="emoji" alt=":smile:"></p>`);
  assert.cooked(":(", `<p><img src="/images/emoji/emoji_one/frowning.png?v=${v}" title=":frowning:" class="emoji" alt=":frowning:"></p>`);
  assert.cooked("8-)", `<p><img src="/images/emoji/emoji_one/sunglasses.png?v=${v}" title=":sunglasses:" class="emoji" alt=":sunglasses:"></p>`);
});

QUnit.test("emoji - emojiSet", assert => {
  assert.cookedOptions(":smile:",
                { emojiSet: 'twitter' },
                `<p><img src="/images/emoji/twitter/smile.png?v=${v}" title=":smile:" class="emoji" alt=":smile:"></p>`);
});
