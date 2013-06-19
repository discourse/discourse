/*global module:true test:true ok:true visit:true equal:true exists:true count:true equal:true present:true md5:true sanitizeHtml:true */

module("Discourse.Markdown");

var cooked = function(input, expected, text) {
  equal(Discourse.Markdown.cook(input, {mentionLookup: false }), expected, text);
};

var cookedOptions = function(input, opts, expected, text) {
  equal(Discourse.Markdown.cook(input, opts), expected, text);
}

test("basic cooking", function() {
  cooked("hello", "<p>hello</p>", "surrounds text with paragraphs");
  cooked("1\n2\n3", "<p>1 <br>\n2 <br>\n3</p>", "automatically handles trivial newlines");
});

test("Links", function() {
  cooked("Youtube: http://www.youtube.com/watch?v=1MrpeBRkM5A",
         '<p>Youtube: <a href="http://www.youtube.com/watch?v=1MrpeBRkM5A">http://www.youtube.com/watch?v=1MrpeBRkM5A</a></p>',
         "allows links to contain query params");

  cooked("Derpy: http://derp.com?__test=1",
         '<p>Derpy: <a href="http://derp.com?%5F%5Ftest=1">http://derp.com?__test=1</a></p>',
         "escapes double underscores in URLs");

  cooked("Atwood: www.codinghorror.com",
         '<p>Atwood: <a href="http://www.codinghorror.com">www.codinghorror.com</a></p>',
         "autolinks something that begins with www");

  cooked("Atwood: http://www.codinghorror.com",
         '<p>Atwood: <a href="http://www.codinghorror.com">http://www.codinghorror.com</a></p>',
         "autolinks a URL with http://www");

  cooked("EvilTrout: http://eviltrout.com",
         '<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a></p>',
         "autolinks a URL");

  cooked("here is [an example](http://twitter.com)",
         '<p>here is <a href="http://twitter.com">an example</a></p>',
         "supports markdown style links");

  cooked("Batman: http://en.wikipedia.org/wiki/The_Dark_Knight_(film)",
         '<p>Batman: <a href="http://en.wikipedia.org/wiki/The_Dark_Knight_(film)">http://en.wikipedia.org/wiki/The_Dark_Knight_(film)</a></p>',
         "autolinks a URL with parentheses (like Wikipedia)");
});

test("Quotes", function() {
  cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function(name) { return "" + name; } },
                "<p>1</p><aside class='quote' data-post=\"1\" >\n  <div class='title'>\n    <div class='quote-controls'></div>\n" +
                "  bob\n  bob\n  said:\n  </div>\n  <blockquote>my quote</blockquote>\n</aside>\n<p> <br>\n2</p>",
                "handles quotes properly");

  cookedOptions("1[quote=\"bob, post:1\"]my quote[/quote]2",
                { topicId: 2, lookupAvatar: function(name) { } },
                "<p>1</p><aside class='quote' data-post=\"1\" >\n  <div class='title'>\n    <div class='quote-controls'></div>\n" +
                "  \n  bob\n  said:\n  </div>\n  <blockquote>my quote</blockquote>\n</aside>\n<p> <br>\n2</p>",
                "includes no avatar if none is found");
});

test("Mentions", function() {
  cookedOptions("Hello @sam", { mentionLookup: (function() { return true; }) },
                "<p>Hello <a href='/users/sam' class='mention'>@sam</a></p>",
                "translates mentions to links");

  cooked("Hello @EvilTrout", "<p>Hello <span class='mention'>@EvilTrout</span></p>", "adds a mention class");
  cooked("robin@email.host", "<p>robin@email.host</p>", "won't add mention class to an email address");
  cooked("hanzo55@yahoo.com", "<p>hanzo55@yahoo.com</p>", "won't be affected by email addresses that have a number before the @ symbol");
  cooked("@EvilTrout yo", "<p><span class='mention'>@EvilTrout</span> yo</p>", "doesn't do @username mentions inside <pre> or <code> blocks");
  cooked("`evil` @EvilTrout `trout`",
         "<p><code>evil</code> <span class='mention'>@EvilTrout</span> <code>trout</code></p>",
         "deals correctly with multiple <code> blocks");

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

  cooked("http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street",
         "<p><a href=\"http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street\" class=\"onebox\" target=\"_blank\"" +
         ">http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street</a></p>",
         "works with links that have underscores in them");

});

test("SanitizeHTML", function() {

  equal(sanitizeHtml("<div><script>alert('hi');</script></div>"), "<div></div>");
  equal(sanitizeHtml("<div><p class=\"funky\" wrong='1'>hello</p></div>"), "<div><p class=\"funky\">hello</p></div>");

});