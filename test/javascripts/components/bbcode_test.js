/*global module:true test:true ok:true visit:true expect:true exists:true count:true equal:true */

module("Discourse.BBCode");

var format = function(input, expected, text) {
  equal(Discourse.BBCode.format(input), expected, text);
}

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