import { module, test } from "qunit";
import sinon from "sinon";
import {
  detectPatternConflicts,
  isBlockPermittedInOutlet,
  isNamespacedPattern,
  matchOutletPattern,
  validateOutletPatterns,
  warnUnknownOutletPatterns,
} from "discourse/lib/blocks/matching/outlet-matcher";

module("Unit | Lib | Blocks | outlet-matcher", function () {
  module("isNamespacedPattern", function () {
    test("returns true for plugin-namespaced patterns", function (assert) {
      assert.true(isNamespacedPattern("my-plugin:dashboard"));
      assert.true(isNamespacedPattern("my-plugin:settings-panel"));
      assert.true(isNamespacedPattern("discourse-ai:chat-sidebar"));
    });

    test("returns true for theme-namespaced patterns", function (assert) {
      assert.true(isNamespacedPattern("my-theme:hero-section"));
      assert.true(isNamespacedPattern("tactile-theme:main-outlet"));
    });

    test("returns false for core outlet patterns", function (assert) {
      assert.false(isNamespacedPattern("sidebar-blocks"));
      assert.false(isNamespacedPattern("homepage-blocks"));
      assert.false(isNamespacedPattern("header-blocks"));
    });

    test("returns false for wildcard patterns without namespace", function (assert) {
      assert.false(isNamespacedPattern("sidebar-*"));
      assert.false(isNamespacedPattern("*-blocks"));
      assert.false(isNamespacedPattern("**"));
    });

    test("returns true for wildcard patterns with namespace", function (assert) {
      assert.true(isNamespacedPattern("my-plugin:*"));
      assert.true(isNamespacedPattern("my-plugin:**"));
      assert.true(isNamespacedPattern("*:outlet"));
    });
  });

  module("matchOutletPattern", function () {
    module("exact match", function () {
      test("matches exact outlet names", function (assert) {
        assert.true(matchOutletPattern("sidebar-blocks", "sidebar-blocks"));
        assert.true(matchOutletPattern("homepage-blocks", "homepage-blocks"));
      });

      test("does not match different names", function (assert) {
        assert.false(matchOutletPattern("sidebar-blocks", "homepage-blocks"));
        assert.false(matchOutletPattern("hero-blocks", "header-blocks"));
      });
    });

    module("single wildcard (*)", function () {
      test("matches any characters", function (assert) {
        assert.true(matchOutletPattern("sidebar-left", "sidebar-*"));
        assert.true(matchOutletPattern("sidebar-right", "sidebar-*"));
        assert.true(matchOutletPattern("sidebar-blocks", "sidebar-*"));
      });

      test("matches multiple hyphen segments (character wildcard)", function (assert) {
        assert.true(matchOutletPattern("sidebar-left-top", "sidebar-*"));
        assert.true(matchOutletPattern("sidebar-right-bottom", "sidebar-*"));
      });

      test("works at start of pattern", function (assert) {
        assert.true(matchOutletPattern("hero-blocks", "*-blocks"));
        assert.true(matchOutletPattern("sidebar-blocks", "*-blocks"));
        assert.true(matchOutletPattern("homepage-blocks", "*-blocks"));
      });

      test("works in middle of pattern", function (assert) {
        assert.true(
          matchOutletPattern("admin-users-settings", "admin-*-settings")
        );
      });

      test("matches empty after prefix (picomatch behavior)", function (assert) {
        // In picomatch, * matches zero or more characters
        assert.true(matchOutletPattern("sidebar-", "sidebar-*"));
      });
    });

    module("double wildcard (**)", function () {
      test("matches everything", function (assert) {
        assert.true(matchOutletPattern("sidebar-blocks", "**"));
        assert.true(matchOutletPattern("anything", "**"));
      });

      test("matches at end", function (assert) {
        assert.true(matchOutletPattern("admin-plugins", "admin-**"));
        assert.true(matchOutletPattern("admin-plugins-settings", "admin-**"));
      });
    });

    module("brace expansion {...}", function () {
      test("matches any option", function (assert) {
        assert.true(
          matchOutletPattern("sidebar-blocks", "{sidebar,homepage}-blocks")
        );
        assert.true(
          matchOutletPattern("homepage-blocks", "{sidebar,homepage}-blocks")
        );
      });

      test("does not match other values", function (assert) {
        assert.false(
          matchOutletPattern("hero-blocks", "{sidebar,homepage}-blocks")
        );
      });

      test("works with wildcards", function (assert) {
        assert.true(matchOutletPattern("sidebar-left", "{sidebar,footer}-*"));
        assert.true(matchOutletPattern("footer-main", "{sidebar,footer}-*"));
        assert.false(matchOutletPattern("header-blocks", "{sidebar,footer}-*"));
      });
    });

    module("character class [...]", function () {
      test("matches characters in class", function (assert) {
        assert.true(matchOutletPattern("modal-1", "modal-[0-9]"));
        assert.true(matchOutletPattern("modal-5", "modal-[0-9]"));
      });

      test("does not match characters outside class", function (assert) {
        assert.false(matchOutletPattern("modal-a", "modal-[0-9]"));
      });

      test("works with wildcards", function (assert) {
        assert.true(matchOutletPattern("modal-1-content", "modal-[0-9]*"));
      });
    });

    module("question mark (?)", function () {
      test("matches single character", function (assert) {
        assert.true(matchOutletPattern("modal-1", "modal-?"));
        assert.true(matchOutletPattern("modal-a", "modal-?"));
      });

      test("does not match multiple characters", function (assert) {
        assert.false(matchOutletPattern("modal-12", "modal-?"));
      });
    });

    module("negation !()", function () {
      test("matches anything except pattern", function (assert) {
        assert.true(matchOutletPattern("sidebar-blocks", "!(*-debug)"));
        assert.true(matchOutletPattern("homepage-blocks", "!(*-debug)"));
        assert.false(matchOutletPattern("sidebar-debug", "!(*-debug)"));
      });
    });

    module("namespaced outlets", function () {
      test("matches namespaced outlet exactly", function (assert) {
        assert.true(
          matchOutletPattern("my-plugin:dashboard", "my-plugin:dashboard")
        );
      });

      test("matches namespaced outlet with wildcard", function (assert) {
        assert.true(matchOutletPattern("my-plugin:dashboard", "my-plugin:*"));
        assert.true(matchOutletPattern("my-plugin:settings", "my-plugin:*"));
      });

      test("matches any namespace with wildcard", function (assert) {
        assert.true(matchOutletPattern("plugin-a:outlet", "*:outlet"));
        assert.true(matchOutletPattern("plugin-b:outlet", "*:outlet"));
      });
    });
  });

  module("validateOutletPatterns", function () {
    test("accepts null (no restrictions)", function (assert) {
      assert.strictEqual(
        validateOutletPatterns(null, "test-block", "allowedOutlets"),
        undefined
      );
    });

    test("accepts undefined (no restrictions)", function (assert) {
      assert.strictEqual(
        validateOutletPatterns(undefined, "test-block", "allowedOutlets"),
        undefined
      );
    });

    test("accepts valid patterns array", function (assert) {
      assert.strictEqual(
        validateOutletPatterns(
          ["sidebar-*", "homepage-blocks"],
          "test-block",
          "allowedOutlets"
        ),
        undefined
      );
    });

    test("accepts empty array", function (assert) {
      assert.strictEqual(
        validateOutletPatterns([], "test-block", "allowedOutlets"),
        undefined
      );
    });

    test("accepts advanced glob patterns", function (assert) {
      assert.strictEqual(
        validateOutletPatterns(
          ["{sidebar,footer}-*", "modal-[0-9]*", "!(*-debug)"],
          "test-block",
          "allowedOutlets"
        ),
        undefined
      );
    });

    test("accepts namespaced patterns", function (assert) {
      assert.strictEqual(
        validateOutletPatterns(
          ["my-plugin:dashboard", "my-theme:*"],
          "test-block",
          "allowedOutlets"
        ),
        undefined
      );
    });
  });

  module("detectPatternConflicts", function () {
    test("returns no conflict for null/undefined lists", function (assert) {
      assert.deepEqual(detectPatternConflicts(null, null), { conflict: false });
      assert.deepEqual(detectPatternConflicts(null, ["sidebar-*"]), {
        conflict: false,
      });
      assert.deepEqual(detectPatternConflicts(["sidebar-*"], null), {
        conflict: false,
      });
      assert.deepEqual(detectPatternConflicts(undefined, ["sidebar-*"]), {
        conflict: false,
      });
    });

    test("returns no conflict for empty lists", function (assert) {
      assert.deepEqual(detectPatternConflicts([], []), { conflict: false });
      assert.deepEqual(detectPatternConflicts([], ["sidebar-*"]), {
        conflict: false,
      });
      assert.deepEqual(detectPatternConflicts(["sidebar-*"], []), {
        conflict: false,
      });
    });

    test("returns no conflict for non-overlapping patterns", function (assert) {
      const result = detectPatternConflicts(["sidebar-*"], ["homepage-*"]);
      assert.deepEqual(result, { conflict: false });
    });

    test("detects conflict with exact same pattern", function (assert) {
      const result = detectPatternConflicts(
        ["sidebar-blocks"],
        ["sidebar-blocks"]
      );
      assert.true(result.conflict);
      assert.strictEqual(result.details.outlet, "sidebar-blocks");
    });

    test("detects conflict when known outlet matches both", function (assert) {
      const result = detectPatternConflicts(["*-blocks"], ["sidebar-*"]);
      assert.true(result.conflict);
      assert.strictEqual(result.details.outlet, "sidebar-blocks");
    });

    test("detects conflict with synthetic test strings", function (assert) {
      const result = detectPatternConflicts(["custom-*"], ["custom-*"]);
      assert.true(result.conflict);
    });

    test("detects conflict with overlapping wildcard patterns", function (assert) {
      const result = detectPatternConflicts(["test-*"], ["*-outlet"]);
      assert.true(result.conflict);
    });
  });

  module("isBlockPermittedInOutlet", function () {
    module("no restrictions", function () {
      test("permits when both lists are null", function (assert) {
        const result = isBlockPermittedInOutlet("sidebar-blocks", null, null);
        assert.true(result.permitted);
        assert.strictEqual(result.reason, undefined);
      });

      test("permits when both lists are undefined", function (assert) {
        const result = isBlockPermittedInOutlet(
          "sidebar-blocks",
          undefined,
          undefined
        );
        assert.true(result.permitted);
      });
    });

    module("allowedOutlets only", function () {
      test("permits when outlet matches allowed pattern", function (assert) {
        const result = isBlockPermittedInOutlet(
          "sidebar-blocks",
          ["sidebar-*"],
          null
        );
        assert.true(result.permitted);
      });

      test("denies when outlet does not match any allowed pattern", function (assert) {
        const result = isBlockPermittedInOutlet(
          "homepage-blocks",
          ["sidebar-*"],
          null
        );
        assert.false(result.permitted);
        assert.true(
          result.reason.includes("does not match any allowedOutlets pattern")
        );
      });

      test("permits when outlet matches one of multiple allowed patterns", function (assert) {
        const result = isBlockPermittedInOutlet(
          "homepage-blocks",
          ["sidebar-*", "homepage-*"],
          null
        );
        assert.true(result.permitted);
      });

      test("denies when allowedOutlets is empty array (strict whitelist)", function (assert) {
        const result = isBlockPermittedInOutlet("sidebar-blocks", [], null);
        assert.false(result.permitted);
      });
    });

    module("deniedOutlets only", function () {
      test("denies when outlet matches denied pattern", function (assert) {
        const result = isBlockPermittedInOutlet("sidebar-blocks", null, [
          "sidebar-*",
        ]);
        assert.false(result.permitted);
        assert.true(result.reason.includes("matches deniedOutlets pattern"));
      });

      test("permits when outlet does not match any denied pattern", function (assert) {
        const result = isBlockPermittedInOutlet("homepage-blocks", null, [
          "sidebar-*",
        ]);
        assert.true(result.permitted);
      });

      test("denies when outlet matches one of multiple denied patterns", function (assert) {
        const result = isBlockPermittedInOutlet("sidebar-blocks", null, [
          "sidebar-*",
          "modal-*",
        ]);
        assert.false(result.permitted);
      });

      test("permits when deniedOutlets is empty array", function (assert) {
        const result = isBlockPermittedInOutlet("sidebar-blocks", null, []);
        assert.true(result.permitted);
      });
    });

    module("both lists specified", function () {
      test("permits when outlet matches allowed and not denied", function (assert) {
        const result = isBlockPermittedInOutlet(
          "sidebar-left",
          ["sidebar-*"],
          ["sidebar-debug"]
        );
        assert.true(result.permitted);
      });

      test("denies when outlet matches denied (deny wins)", function (assert) {
        const result = isBlockPermittedInOutlet(
          "sidebar-debug",
          ["sidebar-*"],
          ["*-debug"]
        );
        assert.false(result.permitted);
        assert.true(result.reason.includes("matches deniedOutlets pattern"));
      });

      test("denies when outlet matches neither", function (assert) {
        const result = isBlockPermittedInOutlet(
          "homepage-blocks",
          ["sidebar-*"],
          ["modal-*"]
        );
        assert.false(result.permitted);
        assert.true(
          result.reason.includes("does not match any allowedOutlets pattern")
        );
      });
    });

    module("namespaced outlets", function () {
      test("permits namespaced outlet when matches allowed", function (assert) {
        const result = isBlockPermittedInOutlet(
          "my-plugin:dashboard",
          ["my-plugin:*"],
          null
        );
        assert.true(result.permitted);
      });

      test("denies namespaced outlet when matches denied", function (assert) {
        const result = isBlockPermittedInOutlet("my-plugin:debug", null, [
          "*:debug",
        ]);
        assert.false(result.permitted);
      });
    });
  });

  module("warnUnknownOutletPatterns", function (hooks) {
    let consoleSpy;

    hooks.beforeEach(function () {
      consoleSpy = sinon.spy(console, "warn");
    });

    hooks.afterEach(function () {
      consoleSpy.restore();
    });

    test("does not warn for null patterns", function (assert) {
      warnUnknownOutletPatterns(null, "test-block", "allowedOutlets");
      assert.false(consoleSpy.called);
    });

    test("does not warn for empty patterns", function (assert) {
      warnUnknownOutletPatterns([], "test-block", "allowedOutlets");
      assert.false(consoleSpy.called);
    });

    test("does not warn for patterns matching known outlets", function (assert) {
      warnUnknownOutletPatterns(["sidebar-*"], "test-block", "allowedOutlets");
      assert.false(consoleSpy.called);
    });

    test("warns for unregistered namespaced patterns", function (assert) {
      // Namespaced patterns are now validated against registered outlets
      // If a custom outlet is not registered, a warning is issued
      warnUnknownOutletPatterns(
        ["my-plugin:custom-outlet", "my-theme:hero"],
        "test-block",
        "allowedOutlets"
      );
      assert.strictEqual(
        consoleSpy.callCount,
        2,
        "warns for each unregistered namespaced pattern"
      );
    });

    test("warns for patterns not matching any registered outlet", function (assert) {
      warnUnknownOutletPatterns(
        ["unknown-outlet-*"],
        "test-block",
        "allowedOutlets"
      );
      assert.true(consoleSpy.calledOnce);
      assert.true(
        consoleSpy.firstCall.args[0].includes(
          "does not match any registered outlet"
        )
      );
      assert.true(consoleSpy.firstCall.args[0].includes("test-block"));
      assert.true(consoleSpy.firstCall.args[0].includes("allowedOutlets"));
    });

    test("warns for typos in outlet names", function (assert) {
      warnUnknownOutletPatterns(["sidbar-*"], "test-block", "allowedOutlets");
      assert.true(consoleSpy.calledOnce);
    });

    test("warns for each unmatched pattern", function (assert) {
      warnUnknownOutletPatterns(
        ["unknown-a", "unknown-b", "sidebar-*"],
        "test-block",
        "allowedOutlets"
      );
      assert.strictEqual(consoleSpy.callCount, 2);
    });
  });
});
