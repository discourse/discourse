import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { DiscourseDeprecationWorkflow } from "discourse/deprecation-workflow";

module("Unit | deprecation-workflow", function (hooks) {
  setupTest(hooks);

  function makeEnv({
    production = false,
    testing = false,
    railsTesting = false,
  } = {}) {
    return {
      isProduction() {
        return production;
      },
      isTesting() {
        return testing;
      },
      isRailsTesting() {
        return railsTesting;
      },
    };
  }

  module("constructor validations", function () {
    test("validates matchId types", function (assert) {
      assert.throws(
        () =>
          new DiscourseDeprecationWorkflow([
            { handler: "silence", matchId: 123 },
          ]),
        /matchId.*must be a string or a regex/,
        "throws when matchId is not string or RegExp"
      );

      assert.throws(
        () =>
          new DiscourseDeprecationWorkflow([
            { handler: "silence", matchId: { bad: true } },
          ]),
        /matchId.*must be a string or a regex/,
        "throws when matchId is an object"
      );
    });

    test("normalizes env and validates allowed values", function (assert) {
      // env as string should be accepted (normalized to array)
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "silence", matchId: "x", env: "production" },
      ]);
      assert.strictEqual(
        wf.list.length,
        0,
        "no environment set so production-only is not active"
      );

      // invalid env should throw
      assert.throws(
        () =>
          new DiscourseDeprecationWorkflow([
            { handler: "silence", matchId: "y", env: "staging" },
          ]),
        /env.*must be one of/,
        "throws on invalid env value"
      );
    });

    test("normalizes handler array and validates allowed handlers and combinations", function (assert) {
      // handler as string -> normalized to array on list
      const wf1 = new DiscourseDeprecationWorkflow([
        { handler: "silence", matchId: "one" },
      ]);
      assert.deepEqual(
        wf1.list.find((w) => w.matchId === "one")?.handler,
        ["silence"],
        "handler is normalized to an array on list"
      );

      // invalid handler throws
      assert.throws(
        () =>
          new DiscourseDeprecationWorkflow([
            { handler: "nope", matchId: "two" },
          ]),
        /handler.*must be one of/,
        "throws on invalid handler"
      );

      // both log and silence together throws
      assert.throws(
        () =>
          new DiscourseDeprecationWorkflow([
            { handler: ["log", "silence"], matchId: "three" },
          ]),
        /must not include both `log` and `silence`/,
        "throws if both log and silence are present"
      );

      // empty handler array is allowed (defaults to []), should still match for counting/silence checks
      const wf2 = new DiscourseDeprecationWorkflow([{ matchId: "four" }]);
      assert.true(
        wf2.shouldCount("four"),
        "empty handler is accepted and should count"
      );
    });
  });

  module("environment activation", function () {
    test("active workflows when environment is not set", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "log", matchId: "empty-env" }, // env: []
        { handler: "log", matchId: "unset-env", env: ["unset"] },
        { handler: "log", matchId: "dev-only", env: ["development"] },
      ]);

      const ids = wf.list.map((w) => w.matchId);
      assert.deepEqual(
        ids.sort(),
        ["empty-env", "unset-env"].sort(),
        "includes empty env and unset env only when environment is not set"
      );
    });

    test("active workflows in production", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "log", matchId: "always" }, // always included
        { handler: "log", matchId: "prod", env: ["production"] },
        { handler: "log", matchId: "dev", env: ["development"] },
        { handler: "log", matchId: "test", env: ["test"] },
        { handler: "log", matchId: "unset", env: ["unset"] },
      ]);

      wf.setEnvironment(makeEnv({ production: true }));

      const ids = wf.list.map((w) => w.matchId);
      assert.deepEqual(
        ids.sort(),
        ["always", "prod"].sort(),
        "includes always and production only"
      );
    });

    test("active workflows in qunit/test environment", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "log", matchId: "always" },
        { handler: "log", matchId: "qunit", env: ["qunit-test"] },
        { handler: "log", matchId: "generic-test", env: ["test"] },
        { handler: "log", matchId: "rails-test-only", env: ["rails-test"] },
        { handler: "log", matchId: "production", env: ["production"] },
        { handler: "log", matchId: "development", env: ["development"] },
      ]);

      wf.setEnvironment(makeEnv({ testing: true }));

      const ids = wf.list.map((w) => w.matchId);
      assert.deepEqual(
        ids.sort(),
        ["always", "qunit", "generic-test"].sort(),
        "includes always, qunit-test, and test only"
      );
    });

    test("active workflows in rails test environment", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "log", matchId: "always" },
        { handler: "log", matchId: "rails-test", env: ["rails-test"] },
        { handler: "log", matchId: "generic-test", env: ["test"] },
        { handler: "log", matchId: "qunit", env: ["qunit-test"] },
        { handler: "log", matchId: "production", env: ["production"] },
        { handler: "log", matchId: "development", env: ["development"] },
      ]);

      wf.setEnvironment(makeEnv({ railsTesting: true }));

      const ids = wf.list.map((w) => w.matchId);
      assert.deepEqual(
        ids.sort(),
        ["always", "rails-test", "generic-test"].sort(),
        "includes always, rails-test, and test only"
      );
    });

    test("active workflows in development-like env", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "log", matchId: "always" },
        { handler: "log", matchId: "development", env: ["development"] },
        { handler: "log", matchId: "test", env: ["test"] },
        { handler: "log", matchId: "production", env: ["production"] },
        { handler: "log", matchId: "unset", env: ["unset"] },
      ]);

      // environment that returns false for prod/testing/railsTesting falls back to development
      wf.setEnvironment(makeEnv());

      const ids = wf.list.map((w) => w.matchId);
      assert.deepEqual(
        ids.sort(),
        ["always", "development"].sort(),
        "includes always and development only"
      );
    });

    test("setEnvironment updates active workflows", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "log", matchId: "always" },
        { handler: "log", matchId: "prod-only", env: ["production"] },
        { handler: "log", matchId: "dev-only", env: ["development"] },
      ]);

      // initially no env: prod-only not active, always active
      assert.deepEqual(
        wf.list.map((w) => w.matchId).sort(),
        ["always"].sort(),
        "initial list only includes env-agnostic workflows"
      );

      wf.setEnvironment(makeEnv({ production: true }));
      assert.deepEqual(
        wf.list.map((w) => w.matchId).sort(),
        ["always", "prod-only"].sort(),
        "after setting production, prod-only becomes active"
      );

      wf.setEnvironment(makeEnv()); // dev-like
      assert.deepEqual(
        wf.list.map((w) => w.matchId).sort(),
        ["always", "dev-only"].sort(),
        "after switching to development-like env, dev-only becomes active"
      );
    });
  });

  module("behavior helpers", function () {
    test("helpers work with exact match and regex match", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "silence", matchId: "bar.deprecated" },
        { handler: "silence", matchId: /^foo\..+$/ },
      ]);

      // exact match
      assert.true(
        wf.shouldSilence("bar.deprecated"),
        "silences exact-match id"
      );

      // regex match
      assert.true(
        wf.shouldSilence("foo.deprecated"),
        "silences regex-matched id"
      );

      // non-match
      assert.false(
        wf.shouldSilence("no.match"),
        "does not silence when no workflow matches"
      );
    });

    test("shouldLog respects workflow presence and handlers", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "log", matchId: "a" },
        { handler: "silence", matchId: "b" },
        { handler: "counter", matchId: "c" }, // no log -> false
        { handler: ["silence", "counter"], matchId: "d" }, // still no log -> false
      ]);

      assert.true(
        wf.shouldLog("no-config"),
        "unhandled deprecations should log"
      );
      assert.true(wf.shouldLog("a"), "handler with log should log");
      assert.false(wf.shouldLog("b"), "silence handler should not log");
      assert.false(wf.shouldLog("c"), "counter-only should not log");
      assert.false(wf.shouldLog("d"), "silence+counter should not log");
    });

    test("shouldSilence reflects presence of silence handler", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "silence", matchId: "s1" },
        { handler: ["silence", "counter"], matchId: "s2" },
        { handler: "log", matchId: "l" },
        { handler: "counter", matchId: "c" },
      ]);

      assert.true(wf.shouldSilence("s1"), "silence -> true");
      assert.true(wf.shouldSilence("s2"), "silence+counter -> true");
      assert.false(wf.shouldSilence("l"), "log -> false");
      assert.false(wf.shouldSilence("c"), "counter -> false");
      assert.false(wf.shouldSilence("unhandled"), "unhandled -> false");
    });

    test("shouldCount defaults to true and is true with counter even if silenced", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "silence", matchId: "s" },
        { handler: "counter", matchId: "c" },
        { handler: ["silence", "counter"], matchId: "sc" },
        { handler: "log", matchId: "l" },
        { handler: [], matchId: "empty" },
      ]);

      assert.true(wf.shouldCount("unhandled"), "unhandled -> count");
      assert.false(wf.shouldCount("s"), "silence -> do not count");
      assert.true(wf.shouldCount("c"), "counter -> count");
      assert.true(wf.shouldCount("sc"), "silence+counter -> count");
      assert.true(wf.shouldCount("l"), "log only -> count");
      assert.true(wf.shouldCount("empty"), "empty handler -> count");
    });

    test("shouldThrow handles throw and includeUnsilenced", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "throw", matchId: "t" },
        { handler: "log", matchId: "l" },
        { handler: "silence", matchId: "s" },
      ]);

      assert.true(
        wf.shouldThrow("t"),
        "throw handler without includeUnsilenced -> true"
      );
      assert.false(
        wf.shouldThrow("l"),
        "non-throw handler without includeUnsilenced -> false"
      );
      assert.false(
        wf.shouldThrow("s"),
        "silenced handler without includeUnsilenced -> false"
      );
      assert.false(
        wf.shouldThrow("unhandled"),
        "unhandled without includeUnsilenced -> false"
      );

      assert.true(
        wf.shouldThrow("t", true),
        "throw handler with includeUnsilenced -> true"
      );
      assert.true(
        wf.shouldThrow("l", true),
        "non-throw handler with includeUnsilenced -> false"
      );
      assert.false(
        wf.shouldThrow("s", true),
        "silenced handler with includeUnsilenced -> false"
      );
      assert.true(
        wf.shouldThrow("unhandled with includeUnsilenced", true),
        "unhandled without includeUnsilenced -> false"
      );
    });
  });

  test("emberWorkflowList flattens handlers and filters to Ember CLI-compatible ones", function (assert) {
    const wf = new DiscourseDeprecationWorkflow([
      { handler: ["silence", "counter"], matchId: "x" },
      { handler: ["log", "throw"], matchId: "y" },
    ]);

    const flattened = wf.emberWorkflowList
      .map((w) => `${w.matchId}:${w.handler}`)
      .sort();

    // "counter" is not included in Ember CLI workflow output; others are
    assert.deepEqual(
      flattened,
      ["x:silence", "y:log", "y:throw"].sort(),
      "outputs one entry per allowed handler and excludes counter"
    );
  });
});
