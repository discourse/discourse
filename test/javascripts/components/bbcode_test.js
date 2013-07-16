/*global md5:true */
module("Discourse.BBCode");

var format = function(input, expected, text) {
  // testing 1 2 3
  equal(Discourse.BBCode.format(input, {lookupAvatar: false}), expected, text);
};

test('basic bbcode', function() {
  format("[b]strong[/b]", "<span class='bbcode-b'>strong</span>", "bolds text");
  format("[i]emphasis[/i]", "<span class='bbcode-i'>emphasis</span>", "italics text");
  format("[u]underlined[/u]", "<span class='bbcode-u'>underlined</span>", "underlines text");
  format("[s]strikethrough[/s]", "<span class='bbcode-s'>strikethrough</span>", "strikes-through text");
  format("[code]\nx++\n[/code]", "<pre>\nx++\n</pre>", "makes code into pre");
  format("[spoiler]it's a sled[/spoiler]", "<span class=\"spoiler\">it's a sled</span>", "supports spoiler tags");
  format("[img]http://eviltrout.com/eviltrout.png[/img]", "<img src=\"http://eviltrout.com/eviltrout.png\">", "links images");
  format("[url]http://bettercallsaul.com[/url]", "<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>", "supports [url] without a title");
  format("[email]eviltrout@mailinator.com[/email]", "<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>", "supports [email] without a title");
});

test('lists', function() {
  format("[ul][li]option one[/li][/ul]", "<ul><li>option one</li></ul>", "creates an ul");
  format("[ol][li]option one[/li][/ol]", "<ol><li>option one</li></ol>", "creates an ol");
});

test('color', function() {
  format("[color=#00f]blue[/color]", "<span style=\"color: #00f\">blue</span>", "supports [color=] with a short hex value");
  format("[color=#ffff00]yellow[/color]", "<span style=\"color: #ffff00\">yellow</span>", "supports [color=] with a long hex value");
  format("[color=red]red[/color]", "<span style=\"color: red\">red</span>", "supports [color=] with an html color");
  format("[color=javascript:alert('wat')]noop[/color]", "noop", "it performs a noop on invalid input");
});

test('tags with arguments', function() {
  format("[size=35]BIG[/size]", "<span class=\"bbcode-size-35\">BIG</span>", "supports [size=]");
  format("[url=http://bettercallsaul.com]better call![/url]", "<a href=\"http://bettercallsaul.com\">better call!</a>", "supports [url] with a title");
  format("[email=eviltrout@mailinator.com]evil trout[/email]", "<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>", "supports [email] with a title");
  format("[u][i]abc[/i][/u]", "<span class='bbcode-u'><span class='bbcode-i'>abc</span></span>", "can nest tags");
  format("[b]first[/b] [b]second[/b]", "<span class='bbcode-b'>first</span> <span class='bbcode-b'>second</span>", "can bold two things on the same line");
});


test("quotes", function() {

  var post = Discourse.Post.create({
    cooked: "<p><b>lorem</b> ipsum</p>",
    username: "eviltrout",
    post_number: 1,
    topic_id: 2
  });

  var formatQuote = function(val, expected, text) {
    equal(Discourse.BBCode.buildQuoteBBCode(post, val), expected, text);
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

});

test("quote formatting", function() {

  // TODO: This HTML matching is quite ugly.
  format("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]",
         "</p><aside class='quote' data-post=\"1\" data-topic=\"1\" >\n  <div class='title'>\n    " +
         "<div class='quote-controls'></div>\n  \n  eviltrout said:\n  </div>\n  <blockquote>abc</blockquote>\n</aside>\n<p>",
         "renders quotes properly");

  format("[quote=\"eviltrout, post:1, topic:1\"]abc[quote=\"eviltrout, post:2, topic:2\"]nested[/quote][/quote]",
         "</p><aside class='quote' data-post=\"1\" data-topic=\"1\" >\n  <div class='title'>\n    <div " +
         "class='quote-controls'></div>\n  \n  eviltrout said:\n  </div>\n  <blockquote>abc</p><aside " +
         "class='quote' data-post=\"2\" data-topic=\"2\" >\n  <div class='title'>\n    <div class='quote-" +
         "controls'></div>\n  \n  eviltrout said:\n  </div>\n  <blockquote>nested</blockquote>\n</aside>\n<p></blockquote>\n</aside>\n<p>",
         "can nest quotes");

  format("before[quote=\"eviltrout, post:1, topic:1\"]first[/quote]middle[quote=\"eviltrout, post:2, topic:2\"]second[/quote]after",
         "before</p><aside class='quote' data-post=\"1\" data-topic=\"1\" >\n  <div class='title'>\n    <div class='quote-cont" +
         "rols'></div>\n  \n  eviltrout said:\n  </div>\n  <blockquote>first</blockquote>\n</aside>\n<p>middle</p><aside cla" +
         "ss='quote' data-post=\"2\" data-topic=\"2\" >\n  <div class='title'>\n    <div class='quote-controls'></div>\n  \n  " +
         "eviltrout said:\n  </div>\n  <blockquote>second</blockquote>\n</aside>\n<p>after",
         "can handle more than one quote");

});


test("extract quotes", function() {

  var q = "[quote=\"eviltrout, post:1, topic:2\"]hello[/quote]";
  var result = Discourse.BBCode.extractQuotes(q + " world");

  equal(result.text, md5(q) + "\n world");
  present(result.template);

});

