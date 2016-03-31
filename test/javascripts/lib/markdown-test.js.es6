module("Discourse.Markdown", {
  setup: function() {
    Discourse.SiteSettings.traditional_markdown_linebreaks = false;
    Discourse.SiteSettings.default_code_lang = "auto";
  }
});

var cooked = function(input, expected, text) {
  var result = Discourse.Markdown.cook(input, {sanitize: true});
  expected = expected.replace(/\/>/g, ">");
  // result = result.replace("/>", ">");
  equal(result, expected, text);
};

var cookedOptions = function(input, opts, expected, text) {
  equal(Discourse.Markdown.cook(input, opts), expected, text);
};

test("basic cooking", function() {
  cooked("hello", "<p>hello</p>", "surrounds text with paragraphs");
  cooked("**evil**", "<p><strong>evil</strong></p>", "it bolds text.");
  cooked("__bold__", "<p><strong>bold</strong></p>", "it bolds text.");
  cooked("*trout*", "<p><em>trout</em></p>", "it italicizes text.");
  cooked("_trout_", "<p><em>trout</em></p>", "it italicizes text.");
  cooked("***hello***", "<p><strong><em>hello</em></strong></p>", "it can do bold and italics at once.");
  cooked("word_with_underscores", "<p>word_with_underscores</p>", "it doesn't do intraword italics");
  cooked("common/_special_font_face.html.erb", "<p>common/_special_font_face.html.erb</p>", "it doesn't intraword with a slash");
  cooked("hello \\*evil\\*", "<p>hello *evil*</p>", "it supports escaping of asterisks");
  cooked("hello \\_evil\\_", "<p>hello _evil_</p>", "it supports escaping of italics");
  cooked("brussels sprouts are *awful*.", "<p>brussels sprouts are <em>awful</em>.</p>", "it doesn't swallow periods.");
});

test("Nested bold and italics", function() {
  cooked("*this is italic **with some bold** inside*", "<p><em>this is italic <strong>with some bold</strong> inside</em></p>", "it handles nested bold in italics");
});

test("Traditional Line Breaks", function() {
  var input = "1\n2\n3";
  cooked(input, "<p>1<br/>2<br/>3</p>", "automatically handles trivial newlines");

  var traditionalOutput = "<p>1\n2\n3</p>";

  cookedOptions(input,
                {traditional_markdown_linebreaks: true},
                traditionalOutput,
                "It supports traditional markdown via an option");

  Discourse.SiteSettings.traditional_markdown_linebreaks = true;
  cooked(input, traditionalOutput, "It supports traditional markdown via a Site Setting");
});

test("Unbalanced underscores", function() {
  cooked("[evil_trout][1] hello_\n\n[1]: http://eviltrout.com", "<p><a href=\"http://eviltrout.com\">evil_trout</a> hello_</p>");
});

test("Line Breaks", function() {
  cooked("[] first choice\n[] second choice",
         "<p>[] first choice<br/>[] second choice</p>",
         "it handles new lines correctly with [] options");

  cooked("<blockquote>evil</blockquote>\ntrout",
         "<blockquote>evil</blockquote>\n\n<p>trout</p>",
         "it doesn't insert <br> after blockquotes");

  cooked("leading<blockquote>evil</blockquote>\ntrout",
         "leading<blockquote>evil</blockquote>\n\n<p>trout</p>",
         "it doesn't insert <br> after blockquotes with leading text");
});

test("Paragraphs for HTML", function() {
  cooked("<div>hello world</div>", "<div>hello world</div>", "it doesn't surround <div> with paragraphs");
  cooked("<p>hello world</p>", "<p>hello world</p>", "it doesn't surround <p> with paragraphs");
  cooked("<i>hello world</i>", "<p><i>hello world</i></p>", "it surrounds inline <i> html tags with paragraphs");
  cooked("<b>hello world</b>", "<p><b>hello world</b></p>", "it surrounds inline <b> html tags with paragraphs");

});

test("Links", function() {

  cooked("EvilTrout: http://eviltrout.com",
         '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a></p>',
         "autolinks a URL");

  cooked("Youtube: http://www.youtube.com/watch?v=1MrpeBRkM5A",
         '<p>Youtube: <a href="http://www.youtube.com/watch?v=1MrpeBRkM5A">http://www.youtube.com/watch?v=1MrpeBRkM5A</a></p>',
         "allows links to contain query params");

  cooked("Derpy: http://derp.com?__test=1",
         '<p>Derpy: <a href="http://derp.com?__test=1">http://derp.com?__test=1</a></p>',
         "works with double underscores in urls");

  cooked("Derpy: http://derp.com?_test_=1",
         '<p>Derpy: <a href="http://derp.com?_test_=1">http://derp.com?_test_=1</a></p>',
         "works with underscores in urls");

  cooked("Atwood: www.codinghorror.com",
         '<p>Atwood: <a href="http://www.codinghorror.com">www.codinghorror.com</a></p>',
         "autolinks something that begins with www");

  cooked("Atwood: http://www.codinghorror.com",
         '<p>Atwood: <a href="http://www.codinghorror.com">http://www.codinghorror.com</a></p>',
         "autolinks a URL with http://www");

  cooked("EvilTrout: http://eviltrout.com hello",
         '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a> hello</p>',
         "autolinks with trailing text");

  cooked("here is [an example](http://twitter.com)",
         '<p>here is <a href="http://twitter.com">an example</a></p>',
         "supports markdown style links");

  cooked("Batman: http://en.wikipedia.org/wiki/The_Dark_Knight_(film)",
         '<p>Batman: <a href="http://en.wikipedia.org/wiki/The_Dark_Knight_(film)">http://en.wikipedia.org/wiki/The_Dark_Knight_(film)</a></p>',
         "autolinks a URL with parentheses (like Wikipedia)");

  cooked("Here's a tweet:\nhttps://twitter.com/evil_trout/status/345954894420787200",
         "<p>Here's a tweet:<br/><a href=\"https://twitter.com/evil_trout/status/345954894420787200\" class=\"onebox\" target=\"_blank\">https://twitter.com/evil_trout/status/345954894420787200</a></p>",
         "It doesn't strip the new line.");

  cooked("1. View @eviltrout's profile here: http://meta.discourse.org/users/eviltrout/activity<br/>next line.",
        "<ol><li>View <span class=\"mention\">@eviltrout</span>'s profile here: <a href=\"http://meta.discourse.org/users/eviltrout/activity\">http://meta.discourse.org/users/eviltrout/activity</a><br>next line.</li></ol>",
        "allows autolinking within a list without inserting a paragraph.");

  cooked("[3]: http://eviltrout.com", "", "It doesn't autolink markdown link references");

  cooked("[]: http://eviltrout.com", "<p>[]: <a href=\"http://eviltrout.com\">http://eviltrout.com</a></p>", "It doesn't accept empty link references");

  cooked("[b]label[/b]: description", "<p><span class=\"bbcode-b\">label</span>: description</p>", "It doesn't accept BBCode as link references");

  cooked("http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369",
         "<p><a href=\"http://discourse.org\">http://discourse.org</a> and " +
         "<a href=\"http://discourse.org/another_url\">http://discourse.org/another_url</a> and " +
         "<a href=\"http://www.imdb.com/name/nm2225369\">http://www.imdb.com/name/nm2225369</a></p>",
         'allows multiple links on one line');

  cooked("* [Evil Trout][1]\n  [1]: http://eviltrout.com",
         "<ul><li><a href=\"http://eviltrout.com\">Evil Trout</a></li></ul>",
         "allows markdown link references in a list");

  cooked("User [MOD]: Hello!",
         "<p>User [MOD]: Hello!</p>",
         "It does not consider references that are obviously not URLs");

  cooked("<small>http://eviltrout.com</small>", "<p><small><a href=\"http://eviltrout.com\">http://eviltrout.com</a></small></p>", "Links within HTML tags");

  cooked("[http://google.com ... wat](http://discourse.org)",
         "<p><a href=\"http://discourse.org\">http://google.com ... wat</a></p>",
         "it supports linkins within links");

  cooked("[Link](http://www.example.com) (with an outer \"description\")",
         "<p><a href=\"http://www.example.com\">Link</a> (with an outer \"description\")</p>",
         "it doesn't consume closing parens as part of the url");

  cooked("[ul][1]\n\n[1]: http://eviltrout.com",
         "<p><a href=\"http://eviltrout.com\">ul</a></p>",
         "it can use `ul` as a link name");
});

test("simple quotes", function() {
  cooked("> nice!", "<blockquote><p>nice!</p></blockquote>", "it supports simple quotes");
  cooked(" > nice!", "<blockquote><p>nice!</p></blockquote>", "it allows quotes with preceding spaces");
  cooked("> level 1\n> > level 2",
         "<blockquote><p>level 1</p><blockquote><p>level 2</p></blockquote></blockquote>",
         "it allows nesting of blockquotes");
  cooked("> level 1\n>  > level 2",
         "<blockquote><p>level 1</p><blockquote><p>level 2</p></blockquote></blockquote>",
         "it allows nesting of blockquotes with spaces");

  cooked("- hello\n\n  > world\n  > eviltrout",
         "<ul><li>hello</li></ul>\n\n<blockquote><p>world<br/>eviltrout</p></blockquote>",
         "it allows quotes within a list.");

  cooked("- <p>eviltrout</p>",
         "<ul><li><p>eviltrout</p></li></ul>",
         "it allows paragraphs within a list.");


  cooked("  > indent 1\n  > indent 2", "<blockquote><p>indent 1<br/>indent 2</p></blockquote>", "allow multiple spaces to indent");

});

test("Quotes", function() {

  cookedOptions("[quote=\"eviltrout, post: 1\"]\na quote\n\nsecond line\n\nthird line[/quote]",
                { topicId: 2 },
                "<aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout:</div><blockquote>" +
                "<p>a quote</p><p>second line</p><p>third line</p></blockquote></aside>",
                "works with multiple lines");

  cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function(name) { return "" + name; }, sanitize: true },
                "<p>1</p>\n\n<aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>bob" +
                "bob:</div><blockquote><p>my quote</p></blockquote></aside>\n\n<p>2</p>",
                "handles quotes properly");

  cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function() { } },
                "<p>1</p>\n\n<aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>bob:" +
                "</div><blockquote><p>my quote</p></blockquote></aside>\n\n<p>2</p>",
                "includes no avatar if none is found");
});

test("Mentions", function() {

  var alwaysTrue = { mentionLookup: (function() { return "user"; }) };

  cookedOptions("Hello @sam", alwaysTrue,
                "<p>Hello <a class=\"mention\" href=\"/users/sam\">@sam</a></p>",
                "translates mentions to links");

  cooked("[@codinghorror](https://twitter.com/codinghorror)",
         "<p><a href=\"https://twitter.com/codinghorror\">@codinghorror</a></p>",
         "it doesn't do mentions within links");

  cookedOptions("[@codinghorror](https://twitter.com/codinghorror)", alwaysTrue,
         "<p><a href=\"https://twitter.com/codinghorror\">@codinghorror</a></p>",
         "it doesn't do link mentions within links");

  cooked("Hello @EvilTrout",
         "<p>Hello <span class=\"mention\">@EvilTrout</span></p>",
         "adds a mention class");

  cooked("robin@email.host",
         "<p>robin@email.host</p>",
         "won't add mention class to an email address");

  cooked("hanzo55@yahoo.com",
         "<p>hanzo55@yahoo.com</p>",
         "won't be affected by email addresses that have a number before the @ symbol");

  cooked("@EvilTrout yo",
         "<p><span class=\"mention\">@EvilTrout</span> yo</p>",
         "it handles mentions at the beginning of a string");

  cooked("yo\n@EvilTrout",
         "<p>yo<br/><span class=\"mention\">@EvilTrout</span></p>",
         "it handles mentions at the beginning of a new line");

  cooked("`evil` @EvilTrout `trout`",
         "<p><code>evil</code> <span class=\"mention\">@EvilTrout</span> <code>trout</code></p>",
         "deals correctly with multiple <code> blocks");

  cooked("```\na @test\n```",
         "<p><pre><code class=\"lang-auto\">a @test</code></pre></p>",
         "should not do mentions within a code block.");

  cooked("> foo bar baz @eviltrout",
         "<blockquote><p>foo bar baz <span class=\"mention\">@eviltrout</span></p></blockquote>",
         "handles mentions in simple quotes");

  cooked("> foo bar baz @eviltrout ohmagerd\nlook at this",
         "<blockquote><p>foo bar baz <span class=\"mention\">@eviltrout</span> ohmagerd<br/>look at this</p></blockquote>",
         "does mentions properly with trailing text within a simple quote");

  cooked("`code` is okay before @mention",
         "<p><code>code</code> is okay before <span class=\"mention\">@mention</span></p>",
         "Does not mention in an inline code block");

  cooked("@mention is okay before `code`",
         "<p><span class=\"mention\">@mention</span> is okay before <code>code</code></p>",
         "Does not mention in an inline code block");

  cooked("don't `@mention`",
         "<p>don't <code>@mention</code></p>",
         "Does not mention in an inline code block");

  cooked("Yes `@this` should be code @eviltrout",
         "<p>Yes <code>@this</code> should be code <span class=\"mention\">@eviltrout</span></p>",
         "Does not mention in an inline code block");

  cooked("@eviltrout and `@eviltrout`",
         "<p><span class=\"mention\">@eviltrout</span> and <code>@eviltrout</code></p>",
         "you can have a mention in an inline code block following a real mention.");

  cooked("1. this is  a list\n\n2. this is an @eviltrout mention\n",
         "<ol><li><p>this is  a list</p></li><li><p>this is an <span class=\"mention\">@eviltrout</span> mention</p></li></ol>",
         "it mentions properly in a list.");

  cooked("Hello @foo/@bar",
         "<p>Hello <span class=\"mention\">@foo</span>/<span class=\"mention\">@bar</span></p>",
         "handles mentions separated by a slash.");

  cookedOptions("@eviltrout", alwaysTrue,
                "<p><a class=\"mention\" href=\"/users/eviltrout\">@eviltrout</a></p>",
                "it doesn't onebox mentions");

  cookedOptions("<small>a @sam c</small>", alwaysTrue,
                "<p><small>a <a class=\"mention\" href=\"/users/sam\">@sam</a> c</small></p>",
                "it allows mentions within HTML tags");
});

test("Category hashtags", () => {
  var alwaysTrue = { categoryHashtagLookup: (function() { return ["http://test.discourse.org/category-hashtag", "category-hashtag"]; }) };

  cookedOptions("Check out #category-hashtag", alwaysTrue,
         "<p>Check out <a class=\"hashtag\" href=\"http://test.discourse.org/category-hashtag\">#<span>category-hashtag</span></a></p>",
         "it translates category hashtag into links");

  cooked("Check out #category-hashtag",
         "<p>Check out <span class=\"hashtag\">#category-hashtag</span></p>",
         "it does not translate category hashtag into links if it is not a valid category hashtag");

  cookedOptions("[#category-hashtag](http://www.test.com)", alwaysTrue,
         "<p><a href=\"http://www.test.com\">#category-hashtag</a></p>",
         "it does not translate category hashtag within links");

  cooked("```\n# #category-hashtag\n```",
         "<p><pre><code class=\"lang-auto\"># #category-hashtag</code></pre></p>",
         "it does not translate category hashtags to links in code blocks");

  cooked("># #category-hashtag\n",
         "<blockquote><h1><span class=\"hashtag\">#category-hashtag</span></h1></blockquote>",
         "it handles category hashtags in simple quotes");

  cooked("# #category-hashtag",
         "<h1><span class=\"hashtag\">#category-hashtag</span></h1>",
         "it works within ATX-style headers");

  cooked("don't `#category-hashtag`",
         "<p>don't <code>#category-hashtag</code></p>",
         "it does not mention in an inline code block");

  cooked("test #hashtag1/#hashtag2",
         "<p>test <span class=\"hashtag\">#hashtag1</span>/#hashtag2</p>",
         "it does not convert category hashtag not bounded by spaces");

  cooked("<small>#category-hashtag</small>",
         "<p><small><span class=\"hashtag\">#category-hashtag</span></small></p>",
         "it works between HTML tags");
});


test("Heading", function() {
  cooked("**Bold**\n----------", "<h2><strong>Bold</strong></h2>", "It will bold the heading");
});

test("bold and italics", function() {
  cooked("a \"**hello**\"", "<p>a \"<strong>hello</strong>\"</p>", "bolds in quotes");
  cooked("(**hello**)", "<p>(<strong>hello</strong>)</p>", "bolds in parens");
  cooked("**hello**\nworld", "<p><strong>hello</strong><br>world</p>", "allows newline after bold");
  cooked("**hello**\n**world**", "<p><strong>hello</strong><br><strong>world</strong></p>", "newline between two bolds");
  cooked("**a*_b**", "<p><strong>a*_b</strong></p>", "allows for characters within bold");
  cooked("** hello**", "<p>** hello**</p>", "does not bold on a space boundary");
  cooked("**hello **", "<p>**hello **</p>", "does not bold on a space boundary");
  cooked("你**hello**", "<p>你**hello**</p>", "does not bold chinese intra word");
  cooked("**你hello**", "<p><strong>你hello</strong></p>", "allows bolded chinese");
});

test("Escaping", function() {
  cooked("*\\*laughs\\**", "<p><em>*laughs*</em></p>", "allows escaping strong");
  cooked("*\\_laughs\\_*", "<p><em>_laughs_</em></p>", "allows escaping em");
});

test("New Lines", function() {
  // Note: This behavior was discussed and we determined it does not make sense to do this
  // unless you're using traditional line breaks
  cooked("_abc\ndef_", "<p>_abc<br>def_</p>", "it does not allow markup to span new lines");
  cooked("_abc\n\ndef_", "<p>_abc</p>\n\n<p>def_</p>", "it does not allow markup to span new paragraphs");
});

test("Oneboxing", function() {

  var matches = function(input, regexp) {
    return Discourse.Markdown.cook(input).match(regexp);
  };

  ok(!matches("- http://www.textfiles.com/bbs/MINDVOX/FORUMS/ethics\n\n- http://drupal.org", /onebox/),
              "doesn't onebox a link within a list");

  ok(matches("http://test.com", /onebox/), "adds a onebox class to a link on its own line");
  ok(matches("http://test.com\nhttp://test2.com", /onebox[\s\S]+onebox/m), "supports multiple links");
  ok(!matches("http://test.com bob", /onebox/), "doesn't onebox links that have trailing text");

  ok(!matches("[Tom Cruise](http://www.tomcruise.com/)", "onebox"), "Markdown links with labels are not oneboxed");
  ok(matches("[http://www.tomcruise.com/](http://www.tomcruise.com/)",
    "onebox"),
    "Markdown links where the label is the same as the url are oneboxed");

  cooked("http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street",
         "<p><a href=\"http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street\" class=\"onebox\"" +
         " target=\"_blank\">http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street</a></p>",
         "works with links that have underscores in them");

});

test("links with full urls", function() {
  cooked("[http://eviltrout.com][1] is a url\n\n[1]: http://eviltrout.com",
         "<p><a href=\"http://eviltrout.com\">http://eviltrout.com</a> is a url</p>",
         "it supports links that are full URLs");
});

test("Code Blocks", function() {

  cooked("<pre>\nhello\n</pre>\n",
         "<p><pre>hello</pre></p>",
         "pre blocks don't include extra lines");

  cooked("```\na\nb\nc\n\nd\n```",
         "<p><pre><code class=\"lang-auto\">a\nb\nc\n\nd</code></pre></p>",
         "it treats new lines properly");

  cooked("```\ntest\n```",
         "<p><pre><code class=\"lang-auto\">test</code></pre></p>",
         "it supports basic code blocks");

  cooked("```json\n{hello: 'world'}\n```\ntrailing",
         "<p><pre><code class=\"lang-json\">{hello: &#x27;world&#x27;}</code></pre></p>\n\n<p>trailing</p>",
         "It does not truncate text after a code block.");

  cooked("```json\nline 1\n\nline 2\n\n\nline3\n```",
         "<p><pre><code class=\"lang-json\">line 1\n\nline 2\n\n\nline3</code></pre></p>",
         "it maintains new lines inside a code block.");

  cooked("hello\nworld\n```json\nline 1\n\nline 2\n\n\nline3\n```",
         "<p>hello<br/>world<br/></p>\n\n<p><pre><code class=\"lang-json\">line 1\n\nline 2\n\n\nline3</code></pre></p>",
         "it maintains new lines inside a code block with leading content.");

  cooked("```ruby\n<header>hello</header>\n```",
         "<p><pre><code class=\"lang-ruby\">&lt;header&gt;hello&lt;/header&gt;</code></pre></p>",
         "it escapes code in the code block");

  cooked("```text\ntext\n```",
         "<p><pre><code class=\"lang-nohighlight\">text</code></pre></p>",
         "handles text by adding nohighlight");

  cooked("```ruby\n# cool\n```",
         "<p><pre><code class=\"lang-ruby\"># cool</code></pre></p>",
         "it supports changing the language");

  cooked("    ```\n    hello\n    ```",
         "<pre><code>&#x60;&#x60;&#x60;\nhello\n&#x60;&#x60;&#x60;</code></pre>",
         "only detect ``` at the beginning of lines");

  cooked("```ruby\ndef self.parse(text)\n\n  text\nend\n```",
         "<p><pre><code class=\"lang-ruby\">def self.parse(text)\n\n  text\nend</code></pre></p>",
         "it allows leading spaces on lines in a code block.");

  cooked("```ruby\nhello `eviltrout`\n```",
         "<p><pre><code class=\"lang-ruby\">hello &#x60;eviltrout&#x60;</code></pre></p>",
         "it allows code with backticks in it");

  cooked("```eviltrout\nhello\n```",
          "<p><pre><code class=\"lang-auto\">hello</code></pre></p>",
          "it doesn't not whitelist all classes");

  cooked("```\n[quote=\"sam, post:1, topic:9441, full:true\"]This is `<not>` a bug.[/quote]\n```",
         "<p><pre><code class=\"lang-auto\">[quote=&quot;sam, post:1, topic:9441, full:true&quot;]This is &#x60;&lt;not&gt;&#x60; a bug.[/quote]</code></pre></p>",
         "it allows code with backticks in it");

  cooked("    hello\n<blockquote>test</blockquote>",
         "<pre><code>hello</code></pre>\n\n<blockquote>test</blockquote>",
         "it allows an indented code block to by followed by a `<blockquote>`");

  cooked("``` foo bar ```",
         "<p><code>foo bar</code></p>",
         "it tolerates misuse of code block tags as inline code");

  cooked("```\nline1\n```\n```\nline2\n\nline3\n```",
         "<p><pre><code class=\"lang-auto\">line1</code></pre></p>\n\n<p><pre><code class=\"lang-auto\">line2\n\nline3</code></pre></p>",
         "it does not consume next block's trailing newlines");

  cooked("    <pre>test</pre>",
         "<pre><code>&lt;pre&gt;test&lt;/pre&gt;</code></pre>",
         "it does not parse other block types in markdown code blocks");

  cooked("    [quote]test[/quote]",
         "<pre><code>[quote]test[/quote]</code></pre>",
         "it does not parse other block types in markdown code blocks");

  cooked("## a\nb\n```\nc\n```",
         "<h2>a</h2>\n\n<p><pre><code class=\"lang-auto\">c</code></pre></p>",
         "it handles headings with code blocks after them.");
});

test("sanitize", function() {
  var sanitize = Discourse.Markdown.sanitize;

  equal(sanitize("<i class=\"fa-bug fa-spin\">bug</i>"), "<i>bug</i>");
  equal(sanitize("<div><script>alert('hi');</script></div>"), "<div></div>");
  equal(sanitize("<div><p class=\"funky\" wrong='1'>hello</p></div>"), "<div><p>hello</p></div>");
  equal(sanitize("<3 <3"), "&lt;3 &lt;3");
  equal(sanitize("<_<"), "&lt;_&lt;");
  cooked("hello<script>alert(42)</script>", "<p>hello</p>", "it sanitizes while cooking");

  cooked("<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>",
         "<p><a href=\"http://disneyland.disney.go.com/\">disney</a> <a href=\"http://reddit.com\">reddit</a></p>",
         "we can embed proper links");

  cooked("<center>hello</center>", "<p>hello</p>", "it does not allow centering");
  cooked("<table><tr><td>hello</td></tr></table>\nafter", "<p>after</p>", "it does not allow tables");
  cooked("<blockquote>a\n</blockquote>\n", "<blockquote>a\n\n<br/>\n\n</blockquote>", "it does not double sanitize");

  cooked("<iframe src=\"http://discourse.org\" width=\"100\" height=\"42\"></iframe>", "", "it does not allow most iframe");

  cooked("<iframe src=\"https://www.google.com/maps/embed?pb=!1m10!1m8!1m3!1d2624.9983685732213!2d2.29432085!3d48.85824149999999!3m2!1i1024!2i768!4f13.1!5e0!3m2!1sen!2s!4v1385737436368\" width=\"100\" height=\"42\"></iframe>",
         "<iframe src=\"https://www.google.com/maps/embed?pb=!1m10!1m8!1m3!1d2624.9983685732213!2d2.29432085!3d48.85824149999999!3m2!1i1024!2i768!4f13.1!5e0!3m2!1sen!2s!4v1385737436368\" width=\"100\" height=\"42\"></iframe>",
         "it allows iframe to google maps");

  cooked("<iframe width=\"425\" height=\"350\" frameborder=\"0\" marginheight=\"0\" marginwidth=\"0\" src=\"http://www.openstreetmap.org/export/embed.html?bbox=22.49454975128174%2C51.220338322410775%2C22.523088455200195%2C51.23345342732931&amp;layer=mapnik\"></iframe>",
         "<iframe width=\"425\" height=\"350\" frameborder=\"0\" marginheight=\"0\" marginwidth=\"0\" src=\"http://www.openstreetmap.org/export/embed.html?bbox=22.49454975128174%2C51.220338322410775%2C22.523088455200195%2C51.23345342732931&amp;layer=mapnik\"></iframe>",
         "it allows iframe to OpenStreetMap");

  equal(sanitize("<textarea>hullo</textarea>"), "hullo");
  equal(sanitize("<button>press me!</button>"), "press me!");
  equal(sanitize("<canvas>draw me!</canvas>"), "draw me!");
  equal(sanitize("<progress>hello"), "hello");
  equal(sanitize("<mark>highlight</mark>"), "highlight");

  cooked("[the answer](javascript:alert(42))", "<p><a>the answer</a></p>", "it prevents XSS");

  cooked("<i class=\"fa fa-bug fa-spin\" style=\"font-size:600%\"></i>\n<!-- -->", "<p><i></i><br/></p>", "it doesn't circumvent XSS with comments");

  cooked("<span class=\"-bbcode-s fa fa-spin\">a</span>", "<p><span>a</span></p>", "it sanitizes spans");
  cooked("<span class=\"fa fa-spin -bbcode-s\">a</span>", "<p><span>a</span></p>", "it sanitizes spans");
  cooked("<span class=\"bbcode-s\">a</span>", "<p><span class=\"bbcode-s\">a</span></p>", "it sanitizes spans");
});

test("URLs in BBCode tags", function() {

  cooked("[img]http://eviltrout.com/eviltrout.png[/img][img]http://samsaffron.com/samsaffron.png[/img]",
         "<p><img src=\"http://eviltrout.com/eviltrout.png\"/><img src=\"http://samsaffron.com/samsaffron.png\"/></p>",
         "images are properly parsed");

  cooked("[url]http://discourse.org[/url]",
         "<p><a href=\"http://discourse.org\">http://discourse.org</a></p>",
         "links are properly parsed");

  cooked("[url=http://discourse.org]discourse[/url]",
         "<p><a href=\"http://discourse.org\">discourse</a></p>",
         "named links are properly parsed");

});

test("urlAllowed", function() {
  var urlAllowed = Discourse.Markdown.urlAllowed;

  var allowed = function(url, msg) {
    equal(urlAllowed(url), url, msg);
  };

  allowed("/foo/bar.html", "allows relative urls");
  allowed("http://eviltrout.com/evil/trout", "allows full urls");
  allowed("https://eviltrout.com/evil/trout", "allows https urls");
  allowed("//eviltrout.com/evil/trout", "allows protocol relative urls");

  equal(urlAllowed("http://google.com/test'onmouseover=alert('XSS!');//.swf"),
        "http://google.com/test%27onmouseover=alert(%27XSS!%27);//.swf",
        "escape single quotes");
});

test("images", function() {
  cooked("[![folksy logo](http://folksy.com/images/folksy-colour.png)](http://folksy.com/)",
         "<p><a href=\"http://folksy.com/\"><img src=\"http://folksy.com/images/folksy-colour.png\" alt=\"folksy logo\"/></a></p>",
         "It allows images with links around them");

  cooked("<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\">",
         "<p><img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\" alt=\"Red dot\"></p>",
         "It allows data images");
});

test("censoring", function() {
  Discourse.SiteSettings.censored_words = "shucks|whiz|whizzer";
  cooked("aw shucks, golly gee whiz.",
         "<p>aw &#9632;&#9632;&#9632;&#9632;&#9632;&#9632;, golly gee &#9632;&#9632;&#9632;&#9632;.</p>",
         "it censors words in the Site Settings");
  cooked("you are a whizzard! I love cheesewhiz. Whiz.",
         "<p>you are a whizzard! I love cheesewhiz. &#9632;&#9632;&#9632;&#9632;.</p>",
         "it doesn't censor words unless they have boundaries.");
  cooked("you are a whizzer! I love cheesewhiz. Whiz.",
         "<p>you are a &#9632;&#9632;&#9632;&#9632;&#9632;&#9632;&#9632;! I love cheesewhiz. &#9632;&#9632;&#9632;&#9632;.</p>",
         "it censors words even if previous partial matches exist.");
});

test("code blocks/spans hoisting", function() {
  cooked("```\n\n    some code\n```",
         "<p><pre><code class=\"lang-auto\">    some code</code></pre></p>",
         "it works when nesting standard markdown code blocks within a fenced code block");

  cooked("`$&`",
         "<p><code>$&amp;</code></p>",
         "it works even when hoisting special replacement patterns");
});
