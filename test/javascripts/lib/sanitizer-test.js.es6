import { default as PrettyText, buildOptions } from 'pretty-text/pretty-text';
import { hrefAllowed } from 'pretty-text/sanitizer';

module("lib:sanitizer");

test("sanitize", function() {
  const pt = new PrettyText(buildOptions({ siteSettings: {} }));
  const cooked = (input, expected, text) => equal(pt.cook(input), expected.replace(/\/>/g, ">"), text);

  equal(pt.sanitize("<i class=\"fa-bug fa-spin\">bug</i>"), "<i>bug</i>");
  equal(pt.sanitize("<div><script>alert('hi');</script></div>"), "<div></div>");
  equal(pt.sanitize("<div><p class=\"funky\" wrong='1'>hello</p></div>"), "<div><p>hello</p></div>");
  equal(pt.sanitize("<3 <3"), "&lt;3 &lt;3");
  equal(pt.sanitize("<_<"), "&lt;_&lt;");
  cooked("hello<script>alert(42)</script>", "<p>hello</p>", "it sanitizes while cooking");

  cooked("<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>",
         "<p><a href=\"http://disneyland.disney.go.com/\">disney</a> <a href=\"http://reddit.com\">reddit</a></p>",
         "we can embed proper links");

  cooked("<center>hello</center>", "<p>hello</p>", "it does not allow centering");
  cooked("<table><tr><td>hello</td></tr></table>\nafter", "<p>after</p>", "it does not allow tables");
  cooked("<blockquote>a\n</blockquote>\n", "<blockquote>a\n\n<br/>\n\n</blockquote>", "it does not double sanitize");

  cooked("<iframe src=\"http://discourse.org\" width=\"100\" height=\"42\"></iframe>", "", "it does not allow most iframes");

  cooked("<iframe src=\"https://www.google.com/maps/embed?pb=!1m10!1m8!1m3!1d2624.9983685732213!2d2.29432085!3d48.85824149999999!3m2!1i1024!2i768!4f13.1!5e0!3m2!1sen!2s!4v1385737436368\" width=\"100\" height=\"42\"></iframe>",
         "<iframe src=\"https://www.google.com/maps/embed?pb=!1m10!1m8!1m3!1d2624.9983685732213!2d2.29432085!3d48.85824149999999!3m2!1i1024!2i768!4f13.1!5e0!3m2!1sen!2s!4v1385737436368\" width=\"100\" height=\"42\"></iframe>",
         "it allows iframe to google maps");

  cooked("<iframe width=\"425\" height=\"350\" frameborder=\"0\" marginheight=\"0\" marginwidth=\"0\" src=\"http://www.openstreetmap.org/export/embed.html?bbox=22.49454975128174%2C51.220338322410775%2C22.523088455200195%2C51.23345342732931&amp;layer=mapnik\"></iframe>",
         "<iframe width=\"425\" height=\"350\" frameborder=\"0\" marginheight=\"0\" marginwidth=\"0\" src=\"http://www.openstreetmap.org/export/embed.html?bbox=22.49454975128174%2C51.220338322410775%2C22.523088455200195%2C51.23345342732931&amp;layer=mapnik\"></iframe>",
         "it allows iframe to OpenStreetMap");

  equal(pt.sanitize("<textarea>hullo</textarea>"), "hullo");
  equal(pt.sanitize("<button>press me!</button>"), "press me!");
  equal(pt.sanitize("<canvas>draw me!</canvas>"), "draw me!");
  equal(pt.sanitize("<progress>hello"), "hello");
  equal(pt.sanitize("<mark>highlight</mark>"), "highlight");

  cooked("[the answer](javascript:alert(42))", "<p><a>the answer</a></p>", "it prevents XSS");

  cooked("<i class=\"fa fa-bug fa-spin\" style=\"font-size:600%\"></i>\n<!-- -->", "<p><i></i><br/></p>", "it doesn't circumvent XSS with comments");

  cooked("<span class=\"-bbcode-s fa fa-spin\">a</span>", "<p><span>a</span></p>", "it sanitizes spans");
  cooked("<span class=\"fa fa-spin -bbcode-s\">a</span>", "<p><span>a</span></p>", "it sanitizes spans");
  cooked("<span class=\"bbcode-s\">a</span>", "<p><span class=\"bbcode-s\">a</span></p>", "it sanitizes spans");
});

test("urlAllowed", function() {
  const allowed = (url, msg) => equal(hrefAllowed(url), url, msg);

  allowed("/foo/bar.html", "allows relative urls");
  allowed("http://eviltrout.com/evil/trout", "allows full urls");
  allowed("https://eviltrout.com/evil/trout", "allows https urls");
  allowed("//eviltrout.com/evil/trout", "allows protocol relative urls");

  equal(hrefAllowed("http://google.com/test'onmouseover=alert('XSS!');//.swf"),
        "http://google.com/test%27onmouseover=alert(%27XSS!%27);//.swf",
        "escape single quotes");
});

