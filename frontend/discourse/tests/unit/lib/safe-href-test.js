/* eslint-disable no-script-url -- this suite intentionally exercises
   `javascript:` and other dangerous-scheme literals to assert they're rejected. */
import { module, test } from "qunit";
import { isSafeHref, safeHref } from "discourse/lib/safe-href";

// Control characters built via fromCharCode so the source stays free of
// raw control bytes.
const TAB = String.fromCharCode(9);
const NEWLINE = String.fromCharCode(10);
const NUL = String.fromCharCode(0);
const DEL = String.fromCharCode(127);

module("Unit | Lib | safe-href", function () {
  module("isSafeHref", function () {
    test("allows the http(s) schemes", function (assert) {
      assert.true(isSafeHref("http://example.com"));
      assert.true(isSafeHref("https://example.com/path?q=1#frag"));
    });

    test("allows mailto and tel", function (assert) {
      assert.true(isSafeHref("mailto:someone@example.com"));
      assert.true(isSafeHref("tel:+15551234567"));
    });

    test("scheme matching is case-insensitive", function (assert) {
      assert.true(isSafeHref("HTTPS://example.com"));
      assert.true(isSafeHref("MailTo:someone@example.com"));
      assert.true(isSafeHref("TEL:123"));
    });

    test("allows relative paths, fragments, and query-only hrefs", function (assert) {
      assert.true(isSafeHref("/categories"));
      assert.true(isSafeHref("/c/general/1?page=2"));
      assert.true(isSafeHref("#section"));
      assert.true(isSafeHref("#"));
      assert.true(isSafeHref("?q=term"));
    });

    test("allows protocol-relative URLs (they start with a slash)", function (assert) {
      assert.true(isSafeHref("//cdn.example.com/logo.png"));
    });

    test("treats bare scheme-less strings as safe (relative refs)", function (assert) {
      // No recognised scheme and not a control/whitespace bypass → safe.
      assert.true(isSafeHref("example.com/path"));
      assert.true(isSafeHref("image.png"));
    });

    test("ignores surrounding whitespace around a safe URL", function (assert) {
      assert.true(isSafeHref("  https://example.com  "));
    });

    test("rejects javascript: in any casing", function (assert) {
      assert.false(isSafeHref("javascript:alert(1)"));
      assert.false(isSafeHref("JavaScript:alert(1)"));
      assert.false(isSafeHref("JAVASCRIPT:void(0)"));
    });

    test("rejects leading-whitespace attempts to smuggle a dangerous scheme", function (assert) {
      // Browsers strip leading spaces before resolving the scheme, so this
      // would execute if treated as scheme-less.
      assert.false(isSafeHref(" javascript:alert(1)"));
      assert.false(isSafeHref("   javascript:alert(1)"));
    });

    test("rejects other dangerous / non-allowlisted schemes", function (assert) {
      assert.false(isSafeHref("data:text/html;base64,PHN2Zz4="));
      assert.false(isSafeHref("vbscript:msgbox(1)"));
      assert.false(isSafeHref("file:///etc/passwd"));
      assert.false(isSafeHref("ftp://example.com/file"));
    });

    test("rejects hrefs containing control characters", function (assert) {
      // A tab / newline smuggled into the scheme, plus NUL and DEL anywhere —
      // browsers may strip these and resolve the scheme.
      assert.false(isSafeHref("java" + TAB + "script:alert(1)"));
      assert.false(isSafeHref("java" + NEWLINE + "script:alert(1)"));
      assert.false(isSafeHref("http://exam" + NUL + "ple.com"));
      assert.false(isSafeHref("https://e" + DEL + "xample.com"));
    });

    test("rejects empty and whitespace-only strings", function (assert) {
      assert.false(isSafeHref(""));
      assert.false(isSafeHref("   "));
    });

    test("rejects non-string inputs", function (assert) {
      assert.false(isSafeHref(null));
      assert.false(isSafeHref(undefined));
      assert.false(isSafeHref(123));
      assert.false(isSafeHref({}));
      assert.false(isSafeHref([]));
      assert.false(isSafeHref(true));
    });
  });

  module("safeHref", function () {
    test("returns the href unchanged when it is safe", function (assert) {
      assert.strictEqual(
        safeHref("https://example.com/a?b=1"),
        "https://example.com/a?b=1"
      );
      assert.strictEqual(safeHref("/relative/path"), "/relative/path");
      assert.strictEqual(safeHref("#"), "#");
      assert.strictEqual(safeHref("mailto:x@y.com"), "mailto:x@y.com");
    });

    test("coalesces unsafe hrefs to '#'", function (assert) {
      assert.strictEqual(safeHref("javascript:alert(1)"), "#");
      assert.strictEqual(safeHref(" javascript:alert(1)"), "#");
      assert.strictEqual(safeHref("data:text/html,<script>"), "#");
      assert.strictEqual(safeHref(""), "#");
    });

    test("coalesces non-string inputs to '#'", function (assert) {
      assert.strictEqual(safeHref(null), "#");
      assert.strictEqual(safeHref(undefined), "#");
      assert.strictEqual(safeHref(42), "#");
      assert.strictEqual(safeHref({}), "#");
    });
  });
});
