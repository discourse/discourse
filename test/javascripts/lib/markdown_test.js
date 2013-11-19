/*global sanitizeHtml:true */

module("Discourse.Markdown", {
  setup: function() {
    Discourse.SiteSettings.traditional_markdown_linebreaks = false;
  }
});

var cooked = function(input, expected, text) {
  var result = Discourse.Markdown.cook(input, {mentionLookup: false, sanitize: true});

  if (result !== expected) {
    console.log(JSON.stringify(result));
    console.log(JSON.stringify(expected));
  }

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
  cooked("brussel sproutes are *awful*.", "<p>brussel sproutes are <em>awful</em>.</p>", "it doesn't swallow periods.");
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
});

test("simple quotes", function() {
  cooked("> nice!", "<blockquote><p>nice!</p></blockquote>", "it supports simple quotes");
  cooked(" > nice!", "<blockquote><p>nice!</p></blockquote>", "it allows quotes with preceeding spaces");
  cooked("> level 1\n> > level 2",
         "<blockquote><p>level 1</p><blockquote><p>level 2</p></blockquote></blockquote>",
         "it allows nesting of blockquotes");
  cooked("> level 1\n>  > level 2",
         "<blockquote><p>level 1</p><blockquote><p>level 2</p></blockquote></blockquote>",
         "it allows nesting of blockquotes with spaces");

  cooked("- hello\n\n  > world\n  > eviltrout",
         "<ul><li>hello</li></ul>\n\n<blockquote><p>world<br/>eviltrout</p></blockquote>",
         "it allows quotes within a list.");
  cooked("  > indent 1\n  > indent 2", "<blockquote><p>indent 1<br/>indent 2</p></blockquote>", "allow multiple spaces to indent");

});

test("Quotes", function() {

  cookedOptions("[quote=\"eviltrout, post: 1\"]\na quote\n\nsecond line\n\nthird line[/quote]",
                { topicId: 2 },
                "<p><aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout said:</div><blockquote>" +
                "<p>a quote</p><p>second line</p><p>third line</p></blockquote></aside></p>",
                "works with multiple lines");

  cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function(name) { return "" + name; }, sanitize: true },
                "<p>1</p>\n\n<p><aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>bob" +
                "bob said:</div><blockquote><p>my quote</p></blockquote></aside></p>\n\n<p>2</p>",
                "handles quotes properly");

  cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function(name) { } },
                "<p>1</p>\n\n<p><aside class=\"quote\" data-post=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>bob said:" +
                "</div><blockquote><p>my quote</p></blockquote></aside></p>\n\n<p>2</p>",
                "includes no avatar if none is found");
});

test("Mentions", function() {

  var alwaysTrue = { mentionLookup: (function() { return true; }) };

  cookedOptions("Hello @sam", alwaysTrue,
                "<p>Hello <a class=\"mention\" href=\"/users/sam\">@sam</a></p>",
                "translates mentions to links");

  cooked("Hello @EvilTrout", "<p>Hello <span class=\"mention\">@EvilTrout</span></p>", "adds a mention class");
  cooked("robin@email.host", "<p>robin@email.host</p>", "won't add mention class to an email address");
  cooked("hanzo55@yahoo.com", "<p>hanzo55@yahoo.com</p>", "won't be affected by email addresses that have a number before the @ symbol");
  cooked("@EvilTrout yo", "<p><span class=\"mention\">@EvilTrout</span> yo</p>", "it handles mentions at the beginning of a string");
  cooked("yo\n@EvilTrout", "<p>yo<br/><span class=\"mention\">@EvilTrout</span></p>", "it handles mentions at the beginning of a new line");
  cooked("`evil` @EvilTrout `trout`",
         "<p><code>evil</code> <span class=\"mention\">@EvilTrout</span> <code>trout</code></p>",
         "deals correctly with multiple <code> blocks");
  cooked("```\na @test\n```", "<p><pre><code class=\"lang-auto\">a @test</code></pre></p>", "should not do mentions within a code block.");

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

  cookedOptions("@eviltrout", alwaysTrue,
                "<p><a class=\"mention\" href=\"/users/eviltrout\">@eviltrout</a></p>",
                "it doesn't onebox mentions");

});


test("Heading", function() {
    cooked("**Bold**\n----------",
           "<h2><strong>Bold</strong></h2>",
           "It will bold the heading");
});

test("Oneboxing", function() {

  var matches = function(input, regexp) {
    return Discourse.Markdown.cook(input, {mentionLookup: false }).match(regexp);
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

  cooked("```\na\nb\nc\n\nd\n```",
         "<p><pre><code class=\"lang-auto\">a\nb\nc\n\nd</code></pre></p>",
         "it treats new lines properly");

  cooked("```\ntest\n```",
         "<p><pre><code class=\"lang-auto\">test</code></pre></p>",
         "it supports basic code blocks");

  cooked("```json\n{hello: 'world'}\n```\ntrailing",
         "<p><pre><code class=\"json\">{hello: &#x27;world&#x27;}</code></pre></p>\n\n<p>trailing</p>",
         "It does not truncate text after a code block.");

  cooked("```json\nline 1\n\nline 2\n\n\nline3\n```",
         "<p><pre><code class=\"json\">line 1\n\nline 2\n\n\nline3</code></pre></p>",
         "it maintains new lines inside a code block.");

  cooked("hello\nworld\n```json\nline 1\n\nline 2\n\n\nline3\n```",
         "<p>hello<br/>world<br/></p>\n\n<p><pre><code class=\"json\">line 1\n\nline 2\n\n\nline3</code></pre></p>",
         "it maintains new lines inside a code block with leading content.");

  cooked("```text\n<header>hello</header>\n```",
         "<p><pre><code class=\"text\">&lt;header&gt;hello&lt;/header&gt;</code></pre></p>",
         "it escapes code in the code block");

  cooked("```ruby\n# cool\n```",
         "<p><pre><code class=\"ruby\"># cool</code></pre></p>",
         "it supports changing the language");

  cooked("    ```\n    hello\n    ```",
         "<pre><code>&#x60;&#x60;&#x60;\nhello\n&#x60;&#x60;&#x60;</code></pre>",
         "only detect ``` at the begining of lines");

  cooked("```ruby\ndef self.parse(text)\n\n  text\nend\n```",
         "<p><pre><code class=\"ruby\">def self.parse(text)\n\n  text\nend</code></pre></p>",
         "it allows leading spaces on lines in a code block.");

  cooked("```ruby\nhello `eviltrout`\n```",
         "<p><pre><code class=\"ruby\">hello &#x60;eviltrout&#x60;</code></pre></p>",
         "it allows code with backticks in it");

  cooked("```eviltrout\nhello\n```",
          "<p><pre><code class=\"lang-auto\">hello</code></pre></p>",
          "it doesn't not whitelist all classes");

  cooked("```[quote=\"sam, post:1, topic:9441, full:true\"]This is `<not>` a bug.[/quote]```",
         "<p><pre><code class=\"lang-auto\">[quote=&quot;sam, post:1, topic:9441, full:true&quot;]This is &#x60;&lt;not&gt;&#x60; a bug.[/quote]</code></pre></p>",
         "it allows code with backticks in it");

});

test("sanitize", function() {
  var sanitize = Discourse.Markdown.sanitize;

  equal(sanitize("<i class=\"icon-bug icon-spin\">bug</i>"), "<i>bug</i>");
  equal(sanitize("<div><script>alert('hi');</script></div>"), "<div></div>");
  equal(sanitize("<div><p class=\"funky\" wrong='1'>hello</p></div>"), "<div><p>hello</p></div>");
  cooked("hello<script>alert(42)</script>", "<p>hello</p>", "it sanitizes while cooking");

  cooked("<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>",
         "<p><a href=\"http://disneyland.disney.go.com/\">disney</a> <a href=\"http://reddit.com\">reddit</a></p>",
         "we can embed proper links");

  cooked("<table><tr><td>hello</td></tr></table>\nafter", "<p>after</p>", "it does not allow tables");
  cooked("<blockquote>a\n</blockquote>\n", "<blockquote>a\n\n<br/>\n\n</blockquote>", "it does not double sanitize");
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
  var allowed = function(url, msg) {
    equal(Discourse.Markdown.urlAllowed(url), url, msg);
  };

  allowed("/foo/bar.html", "allows relative urls");
  allowed("http://eviltrout.com/evil/trout", "allows full urls");
  allowed("https://eviltrout.com/evil/trout", "allows https urls");
  allowed("//eviltrout.com/evil/trout", "allows protocol relative urls");

});
