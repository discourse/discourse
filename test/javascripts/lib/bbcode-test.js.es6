import Quote from 'discourse/lib/quote';

module("Discourse.BBCode");

var format = function(input, expected, text) {
  var cooked = Discourse.Markdown.cook(input, {lookupAvatar: false, sanitize: true});
  equal(cooked, "<p>" + expected + "</p>", text);
};

var formatQ = function(input, expected, text) {
  var cooked = Discourse.Markdown.cook(input, {lookupAvatar: false, sanitize: true});
  equal(cooked, expected, text);
};

test('basic bbcode', function() {
  format("[b]strong[/b]", "<span class=\"bbcode-b\">strong</span>", "bolds text");
  format("[i]emphasis[/i]", "<span class=\"bbcode-i\">emphasis</span>", "italics text");
  format("[u]underlined[/u]", "<span class=\"bbcode-u\">underlined</span>", "underlines text");
  format("[s]strikethrough[/s]", "<span class=\"bbcode-s\">strikethrough</span>", "strikes-through text");
  format("[img]http://eviltrout.com/eviltrout.png[/img]", "<img src=\"http://eviltrout.com/eviltrout.png\">", "links images");
  format("[email]eviltrout@mailinator.com[/email]", "<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>", "supports [email] without a title");
  format("[b]evil [i]trout[/i][/b]",
         "<span class=\"bbcode-b\">evil <span class=\"bbcode-i\">trout</span></span>",
         "allows embedding of tags");
  format("[EMAIL]eviltrout@mailinator.com[/EMAIL]", "<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>", "supports upper case bbcode");
  format("[b]strong [b]stronger[/b][/b]", "<span class=\"bbcode-b\">strong <span class=\"bbcode-b\">stronger</span></span>", "accepts nested bbcode tags");
});

test('urls', function() {
  format("[url]not a url[/url]", "not a url", "supports [url] that isn't a url");
  format("[url]http://bettercallsaul.com[/url]", "<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>", "supports [url] without parameter");
  format("[url=http://example.com]example[/url]", "<a href=\"http://example.com\">example</a>", "supports [url] with given href");
  format("[url=http://www.example.com][img]http://example.com/logo.png[/img][/url]",
         "<a href=\"http://www.example.com\"><img src=\"http://example.com/logo.png\"></a>",
         "supports [url] with an embedded [img]");
});
test('invalid bbcode', function() {
  var cooked = Discourse.Markdown.cook("[code]I am not closed\n\nThis text exists.", {lookupAvatar: false});
  equal(cooked, "<p>[code]I am not closed</p>\n\n<p>This text exists.</p>", "does not raise an error with an open bbcode tag.");
});

test('code', function() {
  format("[code]\nx++\n[/code]", "<pre><code class=\"lang-auto\">x++</code></pre>", "makes code into pre");
  format("[code]\nx++\ny++\nz++\n[/code]", "<pre><code class=\"lang-auto\">x++\ny++\nz++</code></pre>", "makes code into pre");
  format("[code]abc\n#def\n[/code]", '<pre><code class=\"lang-auto\">abc\n#def</code></pre>', 'it handles headings in a [code] block');
  format("[code]\n   s[/code]",
         "<pre><code class=\"lang-auto\">   s</code></pre>",
         "it doesn't trim leading whitespace");
});

test('spoiler', function() {
  format("[spoiler]it's a sled[/spoiler]", "<span class=\"spoiler\">it's a sled</span>", "supports spoiler tags on text");
  format("[spoiler]<img src='http://eviltrout.com/eviltrout.png' width='50' height='50'>[/spoiler]",
         "<span class=\"spoiler\"><img src=\"http://eviltrout.com/eviltrout.png\" width=\"50\" height=\"50\"></span>", "supports spoiler tags on images");
  format("[spoiler] This is the **bold** :smiley: [/spoiler]", "<span class=\"spoiler\"> This is the <strong>bold</strong> <img src=\"/images/emoji/emoji_one/smiley.png?v=0\" title=\":smiley:\" class=\"emoji\" alt=\":smiley:\"> </span>", "supports spoiler tags on emojis");
  format("[spoiler] Why not both <img src='http://eviltrout.com/eviltrout.png' width='50' height='50'>?[/spoiler]", "<span class=\"spoiler\"> Why not both <img src=\"http://eviltrout.com/eviltrout.png\" width=\"50\" height=\"50\">?</span>", "supports images and text");
  format("In a p tag a spoiler [spoiler] <img src='http://eviltrout.com/eviltrout.png' width='50' height='50'>[/spoiler] can work.", "In a p tag a spoiler <span class=\"spoiler\"> <img src=\"http://eviltrout.com/eviltrout.png\" width=\"50\" height=\"50\"></span> can work.", "supports images and text in a p tag");
});

test('lists', function() {
  format("[ul][li]option one[/li][/ul]", "<ul><li>option one</li></ul>", "creates an ul");
  format("[ol][li]option one[/li][/ol]", "<ol><li>option one</li></ol>", "creates an ol");
  format("[ul]\n[li]option one[/li]\n[li]option two[/li]\n[/ul]", "<ul><li>option one</li><li>option two</li></ul>", "suppresses empty lines in lists");
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
  format("[size=35]NEWLINE\n\ntest[/size]",
         "<span class=\"bbcode-size-35\"><p>NEWLINE</p><p>test</p></span>",
         "works with newlines");
  format("[size=35][quote=\"user\"]quote[/quote][/size]",
         "<span class=\"bbcode-size-35\"><aside class=\"quote\"><div class=\"title\"><div class=\"quote-controls\"></div>user:</div><blockquote><p>quote</p></blockquote></aside></span>",
         "works with nested complex blocks");
});

test("quotes", function() {

  var post = Discourse.Post.create({
    cooked: "<p><b>lorem</b> ipsum</p>",
    username: "eviltrout",
    post_number: 1,
    topic_id: 2
  });

  var formatQuote = function(val, expected, text) {
    equal(Quote.build(post, val), expected, text);
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

  format("[quote]\n*test*\n[/quote]",
         "<aside class=\"quote\"><blockquote><p><em>test</em></p></blockquote></aside>",
         "it doesn't insert a new line for italics");

  format("[quote=,script='a'><script>alert('test');//':a][/quote]",
         "<aside class=\"quote\"><blockquote></blockquote></aside>",
         "It will not create a script tag within an attribute");
});

test("quote formatting", function() {

  formatQ("[quote=\"EvilTrout, post:123, topic:456, full:true\"][sam][/quote]",
          "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">" +
          "<div class=\"quote-controls\"></div>EvilTrout:</div><blockquote><p>[sam]</p></blockquote></aside>",
          "it allows quotes with [] inside");

  formatQ("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout:" +
         "</div><blockquote><p>abc</p></blockquote></aside>",
         "renders quotes properly");

  formatQ("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]\nhello",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>eviltrout:" +
         "</div><blockquote><p>abc</p></blockquote></aside>\n\n<p>hello</p>",
         "handles new lines properly");

  formatQ("[quote=\"Alice, post:1, topic:1\"]\n[quote=\"Bob, post:2, topic:1\"]\n[/quote]\n[/quote]",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:" +
         "</div><blockquote><aside class=\"quote\" data-post=\"2\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Bob:" +
         "</div><blockquote></blockquote></aside></blockquote></aside>",
         "quotes can be nested");

  formatQ("[quote=\"Alice, post:1, topic:1\"]\n[quote=\"Bob, post:2, topic:1\"]\n[/quote]",
         "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:" +
         "</div><blockquote><p>[quote=\"Bob, post:2, topic:1\"]</p></blockquote></aside>",
         "handles mismatched nested quote tags");

  formatQ("[quote=\"Alice, post:1, topic:1\"]\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
          "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:</div><blockquote><p><pre><code class=\"lang-javascript\">var foo =&#x27;foo&#x27;;\nvar bar = &#x27;bar&#x27;;</code></pre></p></blockquote></aside>",
          "quotes can have code blocks without leading newline");
  formatQ("[quote=\"Alice, post:1, topic:1\"]\n\n```javascript\nvar foo ='foo';\nvar bar = 'bar';\n```\n[/quote]",
          "<aside class=\"quote\" data-post=\"1\" data-topic=\"1\"><div class=\"title\"><div class=\"quote-controls\"></div>Alice:</div><blockquote><p><pre><code class=\"lang-javascript\">var foo =&#x27;foo&#x27;;\nvar bar = &#x27;bar&#x27;;</code></pre></p></blockquote></aside>",
          "quotes can have code blocks with leading newline");
});

test("quotes with trailing formatting", function() {
  var cooked = Discourse.Markdown.cook("[quote=\"EvilTrout, post:123, topic:456, full:true\"]\nhello\n[/quote]\n*Test*", {lookupAvatar: false});
  equal(cooked,
        "<aside class=\"quote\" data-post=\"123\" data-topic=\"456\" data-full=\"true\"><div class=\"title\">" +
        "<div class=\"quote-controls\"></div>EvilTrout:</div><blockquote><p>hello</p></blockquote></aside>\n\n<p><em>Test</em></p>",
        "it allows trailing formatting");
});


