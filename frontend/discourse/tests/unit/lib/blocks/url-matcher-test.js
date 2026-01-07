import { module, test } from "qunit";
import {
  isShortcut,
  isValidUrlPattern,
  matchesAnyPattern,
  matchUrlPattern,
  normalizePath,
  VALID_SHORTCUTS,
} from "discourse/lib/blocks/url-matcher";
import { setPrefix } from "discourse/lib/get-url";

module("Unit | Lib | Blocks | url-matcher", function (hooks) {
  hooks.beforeEach(function () {
    // Reset URL prefix to empty for clean tests
    setPrefix("");
  });

  module("VALID_SHORTCUTS", function () {
    test("contains expected shortcuts with $ prefix", function (assert) {
      assert.deepEqual(VALID_SHORTCUTS, [
        "$CATEGORY_PAGES",
        "$DISCOVERY_PAGES",
        "$HOMEPAGE",
        "$TAG_PAGES",
        "$TOP_MENU",
      ]);
    });

    test("is frozen", function (assert) {
      assert.true(Object.isFrozen(VALID_SHORTCUTS));
    });
  });

  module("isShortcut", function () {
    test("returns true for patterns starting with $", function (assert) {
      assert.true(isShortcut("$CATEGORY_PAGES"));
      assert.true(isShortcut("$HOMEPAGE"));
      assert.true(isShortcut("$ANYTHING"));
    });

    test("returns false for URL patterns", function (assert) {
      assert.false(isShortcut("/c/**"));
      assert.false(isShortcut("/latest"));
      assert.false(isShortcut("/**"));
    });

    test("returns false for non-strings", function (assert) {
      assert.false(isShortcut(null));
      assert.false(isShortcut(undefined));
      assert.false(isShortcut(123));
      assert.false(isShortcut({}));
    });

    test("returns false for empty string", function (assert) {
      assert.false(isShortcut(""));
    });
  });

  module("isValidUrlPattern", function () {
    test("returns true for valid patterns", function (assert) {
      assert.true(isValidUrlPattern("/c/**"));
      assert.true(isValidUrlPattern("/{latest,top}"));
      assert.true(isValidUrlPattern("/c/[0-9]*"));
      assert.true(isValidUrlPattern("/t/*/123"));
      assert.true(isValidUrlPattern("/**"));
    });

    test("returns false for unbalanced brackets", function (assert) {
      assert.false(isValidUrlPattern("[unclosed"));
      assert.false(isValidUrlPattern("/c/[unclosed"));
    });

    test("returns false for unbalanced braces", function (assert) {
      assert.false(isValidUrlPattern("{unclosed"));
      assert.false(isValidUrlPattern("/{latest,top"));
    });

    test("returns false for unbalanced parentheses", function (assert) {
      assert.false(isValidUrlPattern("!(unclosed"));
      assert.false(isValidUrlPattern("/!(admin"));
    });
  });

  module("normalizePath", function () {
    test("returns / for empty input", function (assert) {
      assert.strictEqual(normalizePath(""), "/");
      assert.strictEqual(normalizePath(null), "/");
      assert.strictEqual(normalizePath(undefined), "/");
    });

    test("preserves root path", function (assert) {
      assert.strictEqual(normalizePath("/"), "/");
    });

    test("removes trailing slash", function (assert) {
      assert.strictEqual(normalizePath("/c/general/"), "/c/general");
      assert.strictEqual(normalizePath("/latest/"), "/latest");
    });

    test("preserves trailing slash for root only", function (assert) {
      assert.strictEqual(normalizePath("/"), "/");
    });

    test("strips query strings", function (assert) {
      assert.strictEqual(normalizePath("/c/general?foo=bar"), "/c/general");
      assert.strictEqual(
        normalizePath("/latest?filter=solved&page=2"),
        "/latest"
      );
    });

    test("strips hash fragments", function (assert) {
      assert.strictEqual(normalizePath("/c/general#section"), "/c/general");
      assert.strictEqual(normalizePath("/t/topic/123#post_5"), "/t/topic/123");
    });

    test("strips both query string and hash", function (assert) {
      assert.strictEqual(
        normalizePath("/c/general?foo=bar#section"),
        "/c/general"
      );
    });

    test("strips subfolder prefix when configured", function (assert) {
      setPrefix("/forum");
      assert.strictEqual(normalizePath("/forum/c/general"), "/c/general");
      assert.strictEqual(normalizePath("/forum/latest"), "/latest");
      assert.strictEqual(normalizePath("/forum/"), "/");
      assert.strictEqual(normalizePath("/forum"), "/");
    });

    test("handles complex subfolder with query and hash", function (assert) {
      setPrefix("/discourse");
      assert.strictEqual(
        normalizePath("/discourse/c/general?foo=bar#section"),
        "/c/general"
      );
    });
  });

  module("matchUrlPattern", function () {
    module("exact match", function () {
      test("matches exact path", function (assert) {
        assert.true(matchUrlPattern("/latest", "/latest"));
        assert.true(matchUrlPattern("/c/general", "/c/general"));
      });

      test("does not match different paths", function (assert) {
        assert.false(matchUrlPattern("/latest", "/top"));
        assert.false(matchUrlPattern("/c/general", "/c/support"));
      });
    });

    module("single wildcard (*)", function () {
      test("matches single path segment", function (assert) {
        assert.true(matchUrlPattern("/c/general", "/c/*"));
        assert.true(matchUrlPattern("/c/support", "/c/*"));
        assert.true(matchUrlPattern("/t/hello", "/t/*"));
      });

      test("does not match multiple path segments", function (assert) {
        assert.false(matchUrlPattern("/c/general/subcategory", "/c/*"));
        assert.false(matchUrlPattern("/c/a/b/c", "/c/*"));
      });

      test("works in middle of pattern", function (assert) {
        assert.true(matchUrlPattern("/t/my-topic/123", "/t/*/123"));
        assert.true(matchUrlPattern("/u/john/summary", "/u/*/summary"));
      });

      test("does not match empty segment", function (assert) {
        assert.false(matchUrlPattern("/c/", "/c/*"));
      });
    });

    module("double wildcard (**)", function () {
      test("matches zero segments", function (assert) {
        assert.true(matchUrlPattern("/c", "/c/**"));
      });

      test("matches single segment", function (assert) {
        assert.true(matchUrlPattern("/c/general", "/c/**"));
      });

      test("matches multiple segments", function (assert) {
        assert.true(matchUrlPattern("/c/general/sub", "/c/**"));
        assert.true(matchUrlPattern("/c/a/b/c/d", "/c/**"));
      });

      test("matches any path with /**", function (assert) {
        assert.true(matchUrlPattern("/", "/**"));
        assert.true(matchUrlPattern("/latest", "/**"));
        assert.true(matchUrlPattern("/c/general/sub", "/**"));
      });

      test("does not match paths outside prefix", function (assert) {
        assert.false(matchUrlPattern("/categories", "/c/**"));
        assert.false(matchUrlPattern("/latest", "/c/**"));
      });
    });

    module("combined wildcards", function () {
      test("* followed by **", function (assert) {
        assert.true(
          matchUrlPattern("/u/john/preferences", "/u/*/preferences/**")
        );
        assert.true(
          matchUrlPattern("/u/john/preferences/account", "/u/*/preferences/**")
        );
        assert.true(
          matchUrlPattern(
            "/u/john/preferences/account/security",
            "/u/*/preferences/**"
          )
        );
      });

      test("multiple * wildcards", function (assert) {
        assert.true(matchUrlPattern("/t/my-topic/123", "/t/*/*"));
        assert.false(matchUrlPattern("/t/my-topic/123/5", "/t/*/*"));
      });
    });

    module("character class [...]", function () {
      test("matches characters in class", function (assert) {
        assert.true(matchUrlPattern("/api/v1", "/api/v[123]"));
        assert.true(matchUrlPattern("/api/v2", "/api/v[123]"));
        assert.true(matchUrlPattern("/api/v3", "/api/v[123]"));
      });

      test("does not match characters outside class", function (assert) {
        assert.false(matchUrlPattern("/api/v4", "/api/v[123]"));
      });

      test("works with wildcards", function (assert) {
        assert.true(matchUrlPattern("/t/slug/123", "/t/*/[0-9]*"));
        assert.false(matchUrlPattern("/t/slug/abc", "/t/*/[0-9]*"));
      });
    });

    module("brace expansion {...}", function () {
      test("matches any option", function (assert) {
        assert.true(matchUrlPattern("/latest", "/{latest,top,new}"));
        assert.true(matchUrlPattern("/top", "/{latest,top,new}"));
        assert.true(matchUrlPattern("/new", "/{latest,top,new}"));
      });

      test("does not match other values", function (assert) {
        assert.false(matchUrlPattern("/unread", "/{latest,top,new}"));
      });

      test("works with paths", function (assert) {
        assert.true(matchUrlPattern("/c/general", "/c/{general,support}"));
        assert.true(matchUrlPattern("/c/support", "/c/{general,support}"));
        assert.false(matchUrlPattern("/c/other", "/c/{general,support}"));
      });
    });

    module("question mark (?)", function () {
      test("matches single character", function (assert) {
        assert.true(matchUrlPattern("/api/v1", "/api/v?"));
        assert.true(matchUrlPattern("/api/v2", "/api/v?"));
      });

      test("does not match multiple characters", function (assert) {
        assert.false(matchUrlPattern("/api/v12", "/api/v?"));
      });

      test("does not match empty", function (assert) {
        assert.false(matchUrlPattern("/api/v", "/api/v?"));
      });
    });
  });

  module("matchesAnyPattern", function () {
    test("returns true when any pattern matches", function (assert) {
      assert.true(matchesAnyPattern("/c/general", ["/c/**", "/tag/*"]));
      assert.true(matchesAnyPattern("/tag/javascript", ["/c/**", "/tag/*"]));
    });

    test("returns false when no pattern matches", function (assert) {
      assert.false(matchesAnyPattern("/latest", ["/c/**", "/tag/*"]));
    });

    test("ignores shortcut patterns", function (assert) {
      assert.false(
        matchesAnyPattern("/c/general", ["$CATEGORY_PAGES", "$HOMEPAGE"])
      );
    });

    test("handles mixed patterns and shortcuts", function (assert) {
      assert.true(
        matchesAnyPattern("/c/general", ["$CATEGORY_PAGES", "/c/**"])
      );
      assert.false(matchesAnyPattern("/latest", ["$CATEGORY_PAGES", "/c/**"]));
    });

    test("returns false for empty patterns array", function (assert) {
      assert.false(matchesAnyPattern("/c/general", []));
    });

    test("returns false when only shortcuts provided", function (assert) {
      assert.false(
        matchesAnyPattern("/c/general", ["$CATEGORY_PAGES", "$HOMEPAGE"])
      );
    });
  });
});
