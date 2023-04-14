import PrettyText, { buildOptions } from "pretty-text/pretty-text";
import { module, test } from "qunit";
import { hrefAllowed, sanitize } from "pretty-text/sanitizer";
import AllowLister from "pretty-text/allow-lister";

module("Unit | Utility | sanitizer", function () {
  test("sanitize", function (assert) {
    const pt = new PrettyText(
      buildOptions({
        siteSettings: {
          allowed_iframes:
            "https://www.google.com/maps/embed?|https://www.openstreetmap.org/export/embed.html?",
        },
      })
    );
    const cooked = (input, expected, text) =>
      assert.strictEqual(pt.cook(input), expected.replace(/\/>/g, ">"), text);

    assert.strictEqual(
      pt.sanitize('<i class="fa-bug fa-spin">bug</i>'),
      "<i>bug</i>"
    );
    assert.strictEqual(
      pt.sanitize("<div><script>alert('hi');</script></div>"),
      "<div></div>"
    );
    assert.strictEqual(
      pt.sanitize("<div><p class=\"funky\" wrong='1'>hello</p></div>"),
      "<div><p>hello</p></div>"
    );
    assert.strictEqual(pt.sanitize("<3 <3"), "&lt;3 &lt;3");
    assert.strictEqual(pt.sanitize("<_<"), "&lt;_&lt;");

    cooked(
      "hello<script>alert(42)</script>",
      "<p>hello</p>",
      "it sanitizes while cooking"
    );

    cooked(
      "<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>",
      '<p><a href="http://disneyland.disney.go.com/">disney</a> <a href="http://reddit.com">reddit</a></p>',
      "we can embed proper links"
    );

    cooked("<center>hello</center>", "hello", "it does not allow centering");
    cooked(
      "<blockquote>a\n</blockquote>\n",
      "<blockquote>a\n</blockquote>",
      "it does not double sanitize"
    );

    cooked(
      '<iframe src="http://discourse.org" width="100" height="42"></iframe>',
      "",
      "it does not allow most iframes"
    );

    cooked(
      '<iframe src="https://www.google.com/maps/embed?pb=!1m10!1m8!1m3!1d2624.9983685732213!2d2.29432085!3d48.85824149999999!3m2!1i1024!2i768!4f13.1!5e0!3m2!1sen!2s!4v1385737436368" width="100" height="42"></iframe>',
      '<iframe src="https://www.google.com/maps/embed?pb=!1m10!1m8!1m3!1d2624.9983685732213!2d2.29432085!3d48.85824149999999!3m2!1i1024!2i768!4f13.1!5e0!3m2!1sen!2s!4v1385737436368" width="100" height="42"></iframe>',
      "it allows iframe to google maps"
    );

    cooked(
      '<iframe width="425" height="350" frameborder="0" marginheight="0" marginwidth="0" src="https://www.openstreetmap.org/export/embed.html?bbox=22.49454975128174%2C51.220338322410775%2C22.523088455200195%2C51.23345342732931&amp;layer=mapnik"></iframe>',
      '<iframe width="425" height="350" frameborder="0" marginheight="0" marginwidth="0" src="https://www.openstreetmap.org/export/embed.html?bbox=22.49454975128174%2C51.220338322410775%2C22.523088455200195%2C51.23345342732931&amp;layer=mapnik"></iframe>',
      "it allows iframe to OpenStreetMap"
    );

    assert.strictEqual(pt.sanitize("<textarea>hullo</textarea>"), "hullo");
    assert.strictEqual(pt.sanitize("<button>press me!</button>"), "press me!");
    assert.strictEqual(pt.sanitize("<canvas>draw me!</canvas>"), "draw me!");
    assert.strictEqual(pt.sanitize("<progress>hello"), "hello");

    cooked(
      "[the answer](javascript:alert(42))",
      "<p>[the answer](javascript:alert(42))</p>",
      "it prevents XSS"
    );

    cooked(
      '<i class="fa fa-bug fa-spin" style="font-size:600%"></i>\n<!-- -->',
      "<p><i></i></p>",
      "it doesn't circumvent XSS with comments"
    );

    cooked(
      '<span class="-bbcode-s fa fa-spin">a</span>',
      "<p><span>a</span></p>",
      "it sanitizes spans"
    );
    cooked(
      '<span class="fa fa-spin -bbcode-s">a</span>',
      "<p><span>a</span></p>",
      "it sanitizes spans"
    );
    cooked(
      '<span class="bbcode-s">a</span>',
      '<p><span class="bbcode-s">a</span></p>',
      "it sanitizes spans"
    );

    cooked(
      "<kbd>Ctrl</kbd>+<kbd>C</kbd>",
      "<p><kbd>Ctrl</kbd>+<kbd>C</kbd></p>"
    );
    cooked(
      "it has been <strike>1 day</strike> 0 days since our last test failure",
      "<p>it has been <strike>1 day</strike> 0 days since our last test failure</p>"
    );
    cooked(
      `it has been <s>1 day</s> 0 days since our last test failure`,
      `<p>it has been <s>1 day</s> 0 days since our last test failure</p>`
    );

    cooked(
      `<div align="center">hello</div>`,
      `<div align="center">hello</div>`
    );

    cooked(
      `1 + 1 is <del>3</del> <ins>2</ins>`,
      `<p>1 + 1 is <del>3</del> <ins>2</ins></p>`
    );
    cooked(
      `<abbr title="JavaScript">JS</abbr>`,
      `<p><abbr title="JavaScript">JS</abbr></p>`
    );
    cooked(
      `<dl><dt>Forum</dt><dd>Software</dd></dl>`,
      `<dl><dt>Forum</dt><dd>Software</dd></dl>`
    );
    cooked(
      `<sup>high</sup> <sub>low</sub> <big>HUGE</big>`,
      `<p><sup>high</sup> <sub>low</sub> <big>HUGE</big></p>`
    );

    cooked(`<div dir="rtl">RTL text</div>`, `<div dir="rtl">RTL text</div>`);

    cooked(
      `<div data-value="<something>" data-html-value="<something>"></div>`,
      `<div data-value="&lt;something&gt;"></div>`
    );
  });

  test("ids on headings", function (assert) {
    const pt = new PrettyText(buildOptions({ siteSettings: {} }));
    assert.strictEqual(
      pt.sanitize("<h3>Test Heading</h3>"),
      "<h3>Test Heading</h3>"
    );
    assert.strictEqual(
      pt.sanitize(`<h1 id="heading--test">Test Heading</h1>`),
      `<h1 id="heading--test">Test Heading</h1>`
    );
    assert.strictEqual(
      pt.sanitize(`<h2 id="heading--cool">Test Heading</h2>`),
      `<h2 id="heading--cool">Test Heading</h2>`
    );
    assert.strictEqual(
      pt.sanitize(`<h3 id="heading--dashed-name">Test Heading</h3>`),
      `<h3 id="heading--dashed-name">Test Heading</h3>`
    );
    assert.strictEqual(
      pt.sanitize(`<h4 id="heading--underscored_name">Test Heading</h4>`),
      `<h4 id="heading--underscored_name">Test Heading</h4>`
    );
    assert.strictEqual(
      pt.sanitize(`<h5 id="heading--trout">Test Heading</h5>`),
      `<h5 id="heading--trout">Test Heading</h5>`
    );
    assert.strictEqual(
      pt.sanitize(`<h6 id="heading--discourse">Test Heading</h6>`),
      `<h6 id="heading--discourse">Test Heading</h6>`
    );
  });

  test("autoplay videos must be muted", function (assert) {
    let pt = new PrettyText(buildOptions({ siteSettings: {} }));
    assert.ok(
      pt
        .sanitize(
          `<p>Hey</p><video autoplay src="http://example.com/music.mp4"/>`
        )
        .match(/muted/)
    );
    assert.ok(
      pt
        .sanitize(
          `<p>Hey</p><video autoplay><source src="http://example.com/music.mp4" type="audio/mpeg"></video>`
        )
        .match(/muted/)
    );
    assert.ok(
      pt
        .sanitize(
          `<p>Hey</p><video autoplay muted><source src="http://example.com/music.mp4" type="audio/mpeg"></video>`
        )
        .match(/muted/)
    );
    assert.notOk(
      pt
        .sanitize(
          `<p>Hey</p><video><source src="http://example.com/music.mp4" type="audio/mpeg"></video>`
        )
        .match(/muted/)
    );
  });

  test("poorly formed ids on headings", function (assert) {
    let pt = new PrettyText(buildOptions({ siteSettings: {} }));
    assert.strictEqual(
      pt.sanitize(`<h1 id="evil-trout">Test Heading</h1>`),
      `<h1>Test Heading</h1>`
    );
    assert.strictEqual(
      pt.sanitize(`<h1 id="heading--">Test Heading</h1>`),
      `<h1>Test Heading</h1>`
    );
    assert.strictEqual(
      pt.sanitize(`<h1 id="heading--with space">Test Heading</h1>`),
      `<h1>Test Heading</h1>`
    );
    assert.strictEqual(
      pt.sanitize(`<h1 id="heading--with*char">Test Heading</h1>`),
      `<h1>Test Heading</h1>`
    );
    assert.strictEqual(
      pt.sanitize(`<h1 id="heading--">Test Heading</h1>`),
      `<h1>Test Heading</h1>`
    );
    assert.strictEqual(
      pt.sanitize(`<h1 id="test-heading--cool">Test Heading</h1>`),
      `<h1>Test Heading</h1>`
    );
  });

  test("urlAllowed", function (assert) {
    const allowed = (url, msg) =>
      assert.strictEqual(hrefAllowed(url), url, msg);

    allowed("/foo/bar.html", "allows relative urls");
    allowed("http://eviltrout.com/evil/trout", "allows full urls");
    allowed("https://eviltrout.com/evil/trout", "allows https urls");
    allowed("//eviltrout.com/evil/trout", "allows protocol relative urls");

    assert.strictEqual(
      hrefAllowed("http://google.com/test'onmouseover=alert('XSS!');//.swf"),
      "http://google.com/test%27onmouseover=alert(%27XSS!%27);//.swf",
      "escape single quotes"
    );
  });

  test("correctly sanitizes complex data attributes rules", function (assert) {
    const allowLister = new AllowLister();

    allowLister.allowListFeature("test", [
      "pre[data-*]",
      "code[data-custom-*=foo]",
      "div[data-cat-*]",
    ]);
    allowLister.enable("test");

    assert.strictEqual(sanitize("<b data-foo=*></b>", allowLister), "<b></b>");
    assert.strictEqual(sanitize("<b data-foo=1></b>", allowLister), "<b></b>");
    assert.strictEqual(sanitize("<b data-=1></b>", allowLister), "<b></b>");
    assert.strictEqual(sanitize("<b data=1></b>", allowLister), "<b></b>");
    assert.strictEqual(sanitize("<b data></b>", allowLister), "<b></b>");
    assert.strictEqual(sanitize("<b data=*></b>", allowLister), "<b></b>");

    assert.strictEqual(
      sanitize("<pre data-foo=1></pre>", allowLister),
      '<pre data-foo="1"></pre>'
    );

    assert.strictEqual(
      sanitize("<pre data-foo-bar=1></pre>", allowLister),
      '<pre data-foo-bar="1"></pre>'
    );

    assert.strictEqual(
      sanitize("<code data-foo=foo></code>", allowLister),
      "<code></code>"
    );

    assert.strictEqual(
      sanitize("<code data-custom-=foo></code>", allowLister),
      "<code></code>"
    );

    assert.strictEqual(
      sanitize("<code data-custom-*=foo></code>", allowLister),
      "<code></code>"
    );

    assert.strictEqual(
      sanitize("<code data-custom-bar=foo></code>", allowLister),
      '<code data-custom-bar="foo"></code>'
    );

    assert.strictEqual(
      sanitize("<code data-custom-bar=1></code>", allowLister),
      "<code></code>"
    );

    assert.strictEqual(
      sanitize("<div data-cat=1></div>", allowLister),
      '<div data-cat="1"></div>'
    );

    assert.strictEqual(
      sanitize("<div data-cat-dog=1></div>", allowLister),
      '<div data-cat-dog="1"></div>'
    );
  });
});
