import {
  avatarImg,
  avatarUrl,
  caretRowCol,
  defaultHomepage,
  emailValid,
  escapeExpression,
  extractDomainFromUrl,
  fillMissingDates,
  getRawSize,
  inCodeBlock,
  initializeDefaultHomepage,
  setCaretPosition,
  setDefaultHomepage,
  slugify,
  toAsciiPrintable,
} from "discourse/lib/utilities";
import { test } from "qunit";
import Handlebars from "handlebars";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";

discourseModule("Unit | Utilities", function () {
  test("escapeExpression", function (assert) {
    assert.strictEqual(
      escapeExpression(">"),
      "&gt;",
      "escapes unsafe characters"
    );

    assert.strictEqual(
      escapeExpression(new Handlebars.SafeString("&gt;")),
      "&gt;",
      "does not double-escape safe strings"
    );

    assert.strictEqual(
      escapeExpression(undefined),
      "",
      "returns a falsy string when given a falsy value"
    );
  });

  test("emailValid", function (assert) {
    assert.ok(
      emailValid("Bob@example.com"),
      "allows upper case in the first part of emails"
    );
    assert.ok(
      emailValid("bob@EXAMPLE.com"),
      "allows upper case in the email domain"
    );
  });

  test("extractDomainFromUrl", function (assert) {
    assert.strictEqual(
      extractDomainFromUrl("http://meta.discourse.org:443/random"),
      "meta.discourse.org",
      "extract domain name from url"
    );
    assert.strictEqual(
      extractDomainFromUrl("meta.discourse.org:443/random"),
      "meta.discourse.org",
      "extract domain regardless of scheme presence"
    );
    assert.strictEqual(
      extractDomainFromUrl("http://192.168.0.1:443/random"),
      "192.168.0.1",
      "works for IP address"
    );
    assert.strictEqual(
      extractDomainFromUrl("http://localhost:443/random"),
      "localhost",
      "works for localhost"
    );
  });

  test("avatarUrl", function (assert) {
    let rawSize = getRawSize;
    assert.blank(avatarUrl("", "tiny"), "no template returns blank");
    assert.strictEqual(
      avatarUrl("/fake/template/{size}.png", "tiny"),
      "/fake/template/" + rawSize(20) + ".png",
      "simple avatar url"
    );
    assert.strictEqual(
      avatarUrl("/fake/template/{size}.png", "large"),
      "/fake/template/" + rawSize(45) + ".png",
      "different size"
    );
  });

  let setDevicePixelRatio = function (value) {
    if (Object.defineProperty && !window.hasOwnProperty("devicePixelRatio")) {
      Object.defineProperty(window, "devicePixelRatio", { value: 2 });
    } else {
      window.devicePixelRatio = value;
    }
  };

  test("avatarImg", function (assert) {
    let oldRatio = window.devicePixelRatio;
    setDevicePixelRatio(2);

    let avatarTemplate = "/path/to/avatar/{size}.png";
    assert.strictEqual(
      avatarImg({ avatarTemplate, size: "tiny" }),
      "<img loading='lazy' alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar'>",
      "it returns the avatar html"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        title: "evilest trout",
      }),
      "<img loading='lazy' alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar' title='evilest trout' aria-label='evilest trout'>",
      "it adds a title if supplied"
    );

    assert.strictEqual(
      avatarImg({
        avatarTemplate,
        size: "tiny",
        extraClasses: "evil fish",
      }),
      "<img loading='lazy' alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar evil fish'>",
      "it adds extra classes if supplied"
    );

    assert.blank(
      avatarImg({ avatarTemplate: "", size: "tiny" }),
      "it doesn't render avatars for invalid avatar template"
    );

    setDevicePixelRatio(oldRatio);
  });

  test("defaultHomepage via meta tag", function (assert) {
    let meta = document.createElement("meta");
    meta.name = "discourse_current_homepage";
    meta.content = "hot";
    document.body.appendChild(meta);
    initializeDefaultHomepage(this.siteSettings);
    assert.strictEqual(
      defaultHomepage(),
      "hot",
      "default homepage is pulled from <meta name=discourse_current_homepage>"
    );
    document.body.removeChild(meta);
  });

  test("defaultHomepage via site settings", function (assert) {
    this.siteSettings.top_menu = "top|latest|hot";
    initializeDefaultHomepage(this.siteSettings);
    assert.strictEqual(
      defaultHomepage(),
      "top",
      "default homepage is the first item in the top_menu site setting"
    );
  });

  test("setDefaultHomepage", function (assert) {
    initializeDefaultHomepage(this.siteSettings);
    assert.strictEqual(defaultHomepage(), "latest");
    setDefaultHomepage("top");
    assert.strictEqual(defaultHomepage(), "top");
  });

  test("caretRowCol", function (assert) {
    let textarea = document.createElement("textarea");
    const content = document.createTextNode("01234\n56789\n012345");
    textarea.appendChild(content);
    document.body.appendChild(textarea);

    const assertResult = (setCaretPos, expectedRowNum, expectedColNum) => {
      setCaretPosition(textarea, setCaretPos);

      const result = caretRowCol(textarea);
      assert.strictEqual(
        result.rowNum,
        expectedRowNum,
        "returns the right row of the caret"
      );
      assert.strictEqual(
        result.colNum,
        expectedColNum,
        "returns the right col of the caret"
      );
    };

    assertResult(0, 1, 0);
    assertResult(5, 1, 5);
    assertResult(6, 2, 0);
    assertResult(11, 2, 5);
    assertResult(14, 3, 2);

    document.body.removeChild(textarea);
  });

  test("toAsciiPrintable", function (assert) {
    const accentedString = "Créme_Brûlée!";
    const unicodeString = "談話";

    assert.strictEqual(
      toAsciiPrintable(accentedString, "discourse"),
      "Creme_Brulee!",
      "it replaces accented characters with the appropriate ASCII equivalent"
    );

    assert.strictEqual(
      toAsciiPrintable(unicodeString, "discourse"),
      "discourse",
      "it uses the fallback string when unable to convert"
    );

    assert.strictEqual(
      typeof toAsciiPrintable(unicodeString),
      "undefined",
      "it returns undefined when unable to convert and no fallback is provided"
    );
  });

  test("slugify", function (assert) {
    const asciiString = "--- 0__( Some-cool Discourse Site! )__0 --- ";
    const accentedString = "Créme_Brûlée!";
    const unicodeString = "談話";

    assert.strictEqual(
      slugify(asciiString),
      "0-some-cool-discourse-site-0",
      "it properly slugifies an ASCII string"
    );

    assert.strictEqual(
      slugify(accentedString),
      "crme-brle",
      "it removes accented characters"
    );

    assert.strictEqual(
      slugify(unicodeString),
      "",
      "it removes unicode characters"
    );
  });

  test("fillMissingDates", function (assert) {
    const startDate = "2017-11-12"; // YYYY-MM-DD
    const endDate = "2017-12-12"; // YYYY-MM-DD
    const data =
      '[{"x":"2017-11-12","y":3},{"x":"2017-11-27","y":2},{"x":"2017-12-06","y":9},{"x":"2017-12-11","y":2}]';

    assert.strictEqual(
      fillMissingDates(JSON.parse(data), startDate, endDate).length,
      31,
      "it returns a JSON array with 31 dates"
    );
  });

  test("inCodeBlock", function (assert) {
    const texts = [
      // closed code blocks
      "000\n\n    111\n\n000",
      "000 `111` 000",
      "000\n```\n111\n```\n000",
      "000\n[code]111[/code]\n000",
      // open code blocks
      "000\n\n    111",
      "000 `111",
      "000\n```\n111",
      "000\n[code]111",
      // complex test
      "000\n\n```\n111\n```\n\n000\n\n`111 111`\n\n000\n\n[code]\n111\n[/code]\n\n    111\n\t111\n\n000`111",
    ];

    texts.forEach((text) => {
      for (let i = 0; i < text.length; ++i) {
        if (text[i] === "0" || text[i] === "1") {
          assert.strictEqual(inCodeBlock(text, i), text[i] === "1");
        }
      }
    });
  });
});
