/*global md5:true */
module("Discourse.BBCode");

var format = function(input, expected, text) {
  var cooked = Discourse.Markdown.cook(input, {lookupAvatar: false});
  equal(cooked, "<p>" + expected + "</p>", text);
};

test('basic bbcode', function() {
  format("[b]strong[/b]", "<span class=\"bbcode-b\">strong</span>", "bolds text");
  format("[i]emphasis[/i]", "<span class=\"bbcode-i\">emphasis</span>", "italics text");
  format("[u]underlined[/u]", "<span class=\"bbcode-u\">underlined</span>", "underlines text");
  format("[s]strikethrough[/s]", "<span class=\"bbcode-s\">strikethrough</span>", "strikes-through text");
  format("[spoiler]it's a sled[/spoiler]", "<span class=\"spoiler\">it's a sled</span>", "supports spoiler tags");
  format("[img]http://eviltrout.com/eviltrout.png[/img]", "<img src=\"http://eviltrout.com/eviltrout.png\"/>", "links images");
  format("[url]http://bettercallsaul.com[/url]", "<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>", "supports [url] without a title");
  format("[email]eviltrout@mailinator.com[/email]", "<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>", "supports [email] without a title");
  format("[b]evil [i]trout[/i][/b]",
         "<span class=\"bbcode-b\">evil <span class=\"bbcode-i\">trout</span></span>",
         "allows embedding of tags");
});

test('invalid bbcode', function() {
  var cooked = Discourse.Markdown.cook("[code]I am not closed\n\nThis text exists.", {lookupAvatar: false});
  equal(cooked, "<p>[code]I am not closed</p>\n\n<p>This text exists.</p>", "does not raise an error with an open bbcode tag.");
});

test('code', function() {
  format("[code]\nx++\n[/code]", "<pre>\nx++</pre>", "makes code into pre");
  format("[code]\nx++\ny++\nz++\n[/code]", "<pre>\nx++\ny++\nz++</pre>", "makes code into pre");
  format("[code]abc\n#def\n[/code]", '<pre>abc\n#def</pre>', 'it handles headings in a [code] block');
});

test('lists', function() {
  format("[ul][li]option one[/li][/ul]", "<ul><li>option one</li></ul>", "creates an ul");
  format("[ol][li]option one[/li][/ol]", "<ol><li>option one</li></ol>", "creates an ol");
});

test('tags with arguments', function() {
  format("[url=http://bettercallsaul.com]better call![/url]", "<a href=\"http://bettercallsaul.com\">better call!</a>", "supports [url] with a title");
  format("[email=eviltrout@mailinator.com]evil trout[/email]", "<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>", "supports [email] with a title");
  format("[u][i]abc[/i][/u]", "<span class=\"bbcode-u\"><span class=\"bbcode-i\">abc</span></span>", "can nest tags");
  format("[b]first[/b] [b]second[/b]", "<span class=\"bbcode-b\">first</span> <span class=\"bbcode-b\">second</span>", "can bold two things on the same line");
});

test("size tags", function() {
  format("[size=35]BIG [b]whoop[/b][/size]",
         "<span class=\"bbcode-size-35\">BIG <span class=\"bbcode-b\">whoop</span></span>",
         "supports [size=]");
  format("[size=asdf]regular[/size]",
         "<span class=\"bbcode-size-1\">regular</span>",
         "it only supports numbers in bbcode");
});

test("quotes", function() {

  var post = Discourse.Post.create({
    cooked: "<p><b>lorem</b> ipsum</p>",
    username: "eviltrout",
    post_number: 1,
    topic_id: 2
  });

  var formatQuote = function(val, expected, text) {
    equal(Discourse.Quote.build(post, val), expected, text);
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

  format("[quote]test[/quote]",
         "<aside class=\"quote\"><blockquote><p>test</p></blockquote></aside>",
         "it supports quotes without params");

});

test("quote formatting", function() {

  format("[quote=\"EvilTrout, post:123, topic:456, full:true\"][sam][/quote]",
          "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">" +
          "<div class=\"quote-controls\"></div>EvilTrout said:</div><blockquote><p>[sam]</p></blockquote></aside>",
          "it allows quotes with [] inside");

  format("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout said:" +
         "</div><blockquote><p>abc</p></blockquote></aside>",
         "renders quotes properly");

  format("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]\nhello",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout said:" +
         "</div><blockquote><p>abc</p></blockquote></aside></p>\n\n<p>hello",
         "handles new lines properly");

});

test("quotes with trailing formatting", function() {
  var cooked = Discourse.Markdown.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]\nhello\n[/quote]\n*Test*", {lookupAvatar: false});
  equal(cooked,
        "<p><aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">" +
        "<div class=\"quote-controls\"></div>EvilTrout said:</div><blockquote><p>hello</p></blockquote></aside></p>\n\n<p><em>Test</em></p>",
        "it allows trailing formatting");
});


