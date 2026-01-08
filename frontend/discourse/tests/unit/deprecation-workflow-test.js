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

      // both notify-admin and silence together throws
      assert.throws(
        () =>
          new DiscourseDeprecationWorkflow([
            { handler: ["notify-admin", "silence"], matchId: "four" },
          ]),
        /must not include both `notify-admin` and `silence`/,
        "throws if both notify-admin and silence are present"
      );

      // empty handler array is allowed (defaults to []), should still match for counting/silence checks
      const wf2 = new DiscourseDeprecationWorkflow([{ matchId: "five" }]);
      assert.true(
        wf2.shouldCount("five"),
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
        { handler: "count", matchId: "c" }, // no log -> false
        { handler: ["silence", "count"], matchId: "d" }, // still no log -> false
      ]);

      assert.true(
        wf.shouldLog("no-config"),
        "unhandled deprecations should log"
      );
      assert.true(wf.shouldLog("a"), "handler with log should log");
      assert.false(wf.shouldLog("b"), "silence handler should not log");
      assert.false(wf.shouldLog("c"), "count-only should not log");
      assert.false(wf.shouldLog("d"), "silence+count should not log");
    });

    test("shouldSilence reflects presence of silence handler", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "silence", matchId: "s1" },
        { handler: ["silence", "count"], matchId: "s2" },
        { handler: "log", matchId: "l" },
        { handler: "count", matchId: "c" },
      ]);

      assert.true(wf.shouldSilence("s1"), "silence -> true");
      assert.true(wf.shouldSilence("s2"), "silence+count -> true");
      assert.false(wf.shouldSilence("l"), "log -> false");
      assert.false(wf.shouldSilence("c"), "count -> false");
      assert.false(wf.shouldSilence("unhandled"), "unhandled -> false");
    });

    test("shouldCount defaults to true and is true with count even if silenced", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "silence", matchId: "s" },
        { handler: "count", matchId: "c" },
        { handler: ["silence", "count"], matchId: "sc" },
        { handler: "log", matchId: "l" },
        { handler: [], matchId: "empty" },
      ]);

      assert.true(wf.shouldCount("unhandled"), "unhandled -> count");
      assert.false(wf.shouldCount("s"), "silence -> do not count");
      assert.true(wf.shouldCount("c"), "count -> count");
      assert.true(wf.shouldCount("sc"), "silence+count -> count");
      assert.true(wf.shouldCount("l"), "log only -> count");
      assert.true(wf.shouldCount("empty"), "empty handler -> count");
    });

    test("shouldCount respects dont-count handler", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "dont-count", matchId: "dc" },
        { handler: ["log", "dont-count"], matchId: "ldc" },
        { handler: ["count", "dont-count"], matchId: "cdc" },
        { handler: "log", matchId: "l" },
      ]);

      assert.false(
        wf.shouldCount("dc"),
        "dont-count handler prevents counting"
      );
      assert.false(
        wf.shouldCount("ldc"),
        "dont-count with log still prevents counting"
      );
      assert.false(wf.shouldCount("cdc"), "dont-count overrides count handler");
      assert.true(wf.shouldCount("l"), "log only should count");
      assert.true(wf.shouldCount("unhandled"), "unhandled should count");
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

    test("shouldThrow respects dont-throw handler", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "dont-throw", matchId: "dt" },
        { handler: ["throw", "dont-throw"], matchId: "tdt" },
        { handler: ["log", "dont-throw"], matchId: "ldt" },
        { handler: "throw", matchId: "t" },
      ]);

      assert.false(
        wf.shouldThrow("dt"),
        "dont-throw handler prevents throwing"
      );
      assert.false(wf.shouldThrow("tdt"), "dont-throw overrides throw handler");
      assert.false(
        wf.shouldThrow("ldt"),
        "dont-throw with log prevents throwing"
      );
      assert.true(wf.shouldThrow("t"), "throw handler should throw");

      assert.false(
        wf.shouldThrow("dt", true),
        "dont-throw prevents throwing even with includeUnsilenced"
      );
      assert.false(
        wf.shouldThrow("tdt", true),
        "dont-throw overrides throw even with includeUnsilenced"
      );
      assert.false(
        wf.shouldThrow("ldt", true),
        "dont-throw with log prevents throwing even with includeUnsilenced"
      );
    });

    test("shouldNotifyAdmin reflects presence of notify-admin handler", function (assert) {
      const wf = new DiscourseDeprecationWorkflow([
        { handler: "notify-admin", matchId: "na1" },
        { handler: ["notify-admin", "count"], matchId: "na2" },
        { handler: "log", matchId: "l" },
        { handler: "silence", matchId: "s" },
      ]);

      assert.true(wf.shouldNotifyAdmin("na1"), "notify-admin handler -> true");
      assert.true(wf.shouldNotifyAdmin("na2"), "notify-admin + count -> true");
      assert.false(wf.shouldNotifyAdmin("l"), "log handler -> false");
      assert.false(wf.shouldNotifyAdmin("s"), "silence handler -> false");
      assert.false(wf.shouldNotifyAdmin("unhandled"), "unhandled -> false");
    });
  });

  test("emberWorkflowList flattens handlers and filters to Ember CLI-compatible ones", function (assert) {
    const wf = new DiscourseDeprecationWorkflow([
      { handler: ["silence", "count"], matchId: "x" },
      { handler: ["log", "throw"], matchId: "y" },
      { handler: ["silence", "dont-throw", "dont-count"], matchId: "z" },
    ]);

    const flattened = wf.emberWorkflowList
      .map((w) => `${w.matchId}:${w.handler}`)
      .sort();

    // "count", "dont-throw", "dont-count" are not included in Ember CLI workflow output; only Ember CLI handlers are
    assert.deepEqual(
      flattened,
      ["x:silence", "y:log", "y:throw", "z:silence"].sort(),
      "outputs one entry per allowed handler and excludes count, dont-throw, and dont-count"
    );
  });
});
