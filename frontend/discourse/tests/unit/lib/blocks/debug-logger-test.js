import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { blockDebugLogger } from "discourse/static/dev-tools/block-debug/debug-logger";

module("Unit | Lib | blocks/debug-logger", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.consoleStub = {
      log: sinon.stub(console, "log"),
      debug: sinon.stub(console, "debug"),
      groupCollapsed: sinon.stub(console, "groupCollapsed"),
      groupEnd: sinon.stub(console, "groupEnd"),
    };
  });

  hooks.afterEach(function () {
    this.consoleStub.log.restore();
    this.consoleStub.debug.restore();
    this.consoleStub.groupCollapsed.restore();
    this.consoleStub.groupEnd.restore();
  });

  module("startGroup", function () {
    test("creates new group entry", function (assert) {
      assert.false(blockDebugLogger.hasActiveGroup());

      blockDebugLogger.startGroup("test-block", "outlet-name");

      assert.true(blockDebugLogger.hasActiveGroup());

      blockDebugLogger.endGroup(true);
    });
  });

  module("logCondition", function () {
    test("adds condition to current group", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "user",
        args: { loggedIn: true },
        result: true,
        depth: 0,
      });
      blockDebugLogger.endGroup(true);

      assert.true(
        this.consoleStub.log.calledOnce,
        "console.log called for condition"
      );
    });

    test("logs standalone when no group active", function (assert) {
      blockDebugLogger.logCondition({
        type: "user",
        args: { loggedIn: true },
        result: true,
        depth: 0,
      });

      assert.true(
        this.consoleStub.debug.calledOnce,
        "console.debug called for standalone condition"
      );
      const [message] = this.consoleStub.debug.firstCall.args;
      assert.true(message.includes("[Blocks]"));
      assert.true(message.includes("user"));
    });
  });

  module("updateCombinatorResult", function () {
    test("updates pending combinator result", function (assert) {
      // Simulates a simple condition tree:
      // AND (depth 0)
      //   user (depth 1)
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "AND",
        args: "2 conditions",
        result: null,
        depth: 0,
      });
      blockDebugLogger.logCondition({
        type: "user",
        args: { loggedIn: true },
        result: true,
        depth: 1,
      });
      blockDebugLogger.updateCombinatorResult(true, 0);
      blockDebugLogger.endGroup(true);

      // groupCollapsed called twice: once for main block, once for AND (has children)
      assert.strictEqual(
        this.consoleStub.groupCollapsed.callCount,
        2,
        "console.groupCollapsed called for main block and AND combinator"
      );
      // log called once for user condition (no children)
      assert.strictEqual(
        this.consoleStub.log.callCount,
        1,
        "one condition logged with console.log"
      );
    });

    test("does nothing when no group active", function (assert) {
      blockDebugLogger.updateCombinatorResult(true, 0);
      assert.true(
        this.consoleStub.log.notCalled,
        "no console output without group"
      );
    });
  });

  module("endGroup", function () {
    test("flushes logs to console", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "user",
        args: { loggedIn: true },
        result: true,
        depth: 0,
      });
      blockDebugLogger.endGroup(true);

      assert.true(
        this.consoleStub.groupCollapsed.calledOnce,
        "console.groupCollapsed called"
      );
      assert.true(
        this.consoleStub.groupEnd.calledOnce,
        "console.groupEnd called"
      );
    });

    test("clears group after flush", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "user",
        args: {},
        result: true,
        depth: 0,
      });
      blockDebugLogger.endGroup(true);

      assert.false(blockDebugLogger.hasActiveGroup());
    });

    test("does nothing with empty logs", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.endGroup(true);

      assert.true(
        this.consoleStub.groupCollapsed.notCalled,
        "no console group for empty logs"
      );
    });

    test("shows RENDERED status for passing blocks", function (assert) {
      blockDebugLogger.startGroup("my-block", "homepage-blocks");
      blockDebugLogger.logCondition({
        type: "user",
        args: {},
        result: true,
        depth: 0,
      });
      blockDebugLogger.endGroup(true);

      const [message] = this.consoleStub.groupCollapsed.firstCall.args;
      assert.true(message.includes("RENDERED"));
      assert.true(message.includes("my-block"));
      assert.true(message.includes("homepage-blocks"));
    });

    test("shows SKIPPED status for failing blocks", function (assert) {
      blockDebugLogger.startGroup("my-block", "homepage-blocks");
      blockDebugLogger.logCondition({
        type: "user",
        args: {},
        result: false,
        depth: 0,
      });
      blockDebugLogger.endGroup(false);

      const [message] = this.consoleStub.groupCollapsed.firstCall.args;
      assert.true(message.includes("SKIPPED"));
    });

    test("does nothing when no group active", function (assert) {
      blockDebugLogger.endGroup(true);

      assert.true(
        this.consoleStub.groupCollapsed.notCalled,
        "no console output without group"
      );
    });
  });

  module("nested groups", function () {
    test("maintains correct hierarchy with nested conditions", function (assert) {
      // Simulates a condition tree with sibling combinators:
      // AND (depth 0)
      //   user (depth 1)
      //   OR (depth 1)
      //     route (depth 2)
      blockDebugLogger.startGroup("outer-block", "outlet-name");

      blockDebugLogger.logCondition({
        type: "AND",
        args: "2 conditions",
        result: null,
        depth: 0,
      });
      blockDebugLogger.logCondition({
        type: "user",
        args: { loggedIn: true },
        result: true,
        depth: 1,
      });
      blockDebugLogger.logCondition({
        type: "OR",
        args: "2 conditions",
        result: null,
        depth: 1,
      });
      blockDebugLogger.logCondition({
        type: "route",
        args: { urls: ["/"] },
        result: true,
        depth: 2,
      });
      blockDebugLogger.updateCombinatorResult(true, 1);
      blockDebugLogger.updateCombinatorResult(true, 0);

      blockDebugLogger.endGroup(true);

      // AND (depth 0) has children (user at depth 1) → groupCollapsed
      // user (depth 1) has no children (OR is at same depth) → log
      // OR (depth 1) has children (route at depth 2) → groupCollapsed
      // route (depth 2) has no children → log
      // Plus the main block group → total groupCollapsed = 3
      assert.strictEqual(
        this.consoleStub.groupCollapsed.callCount,
        3,
        "three groups collapsed (main + AND + OR)"
      );
      assert.strictEqual(
        this.consoleStub.log.callCount,
        2,
        "two conditions logged with console.log (user + route)"
      );
    });

    test("deeply nested conditions maintain proper group hierarchy", function (assert) {
      // Simulates a complex condition tree like:
      // AND (depth 0)
      //   route (depth 1)
      //     route-state (depth 2)
      //     OR (depth 2) - queryParams with { any: [...] }
      //       param-group (depth 3)
      //       param-group (depth 3)
      //   setting (depth 1)
      blockDebugLogger.startGroup("complex-block", "main-outlet");

      // Top-level AND combinator
      blockDebugLogger.logCondition({
        type: "AND",
        args: "2 conditions",
        result: null,
        depth: 0,
      });

      // First child: route condition with nested children
      blockDebugLogger.logCondition({
        type: "route",
        args: { urls: ["/c/**"], queryParams: { any: [] } },
        result: null,
        depth: 1,
      });

      // route-state logged by route condition
      blockDebugLogger.logRouteState({
        currentPath: "/c/general",
        expectedUrls: ["/c/**"],
        excludeUrls: undefined,
        actualParams: { slug: "general" },
        actualQueryParams: { preview_theme_id: "3" },
        depth: 2,
        result: true,
      });

      // OR combinator for queryParams { any: [...] }
      blockDebugLogger.logCondition({
        type: "OR",
        args: "2 queryParams specs",
        result: null,
        depth: 2,
      });

      // First queryParams spec
      blockDebugLogger.logParamGroup({
        label: "queryParams[0]",
        matches: [
          {
            key: "preview_theme_id",
            expected: { any: ["3", "4"] },
            actual: "3",
            result: true,
          },
        ],
        result: true,
        depth: 3,
      });

      // Second queryParams spec
      blockDebugLogger.logParamGroup({
        label: "queryParams[1]",
        matches: [
          {
            key: "preview_theme_id",
            expected: { any: ["6", "7"] },
            actual: "3",
            result: false,
          },
        ],
        result: false,
        depth: 3,
      });

      blockDebugLogger.updateCombinatorResult(true, 2); // OR passed
      blockDebugLogger.updateConditionResult("route", true, 1); // route passed

      // Second child of AND: simple setting condition
      blockDebugLogger.logCondition({
        type: "setting",
        args: { name: "enable_feature" },
        result: true,
        depth: 1,
      });

      blockDebugLogger.updateCombinatorResult(true, 0); // AND passed

      blockDebugLogger.endGroup(true);

      // Expected groupCollapsed calls:
      // 1. Main block group
      // 2. AND (depth 0) - has children at depth 1
      // 3. route (depth 1) - has children at depth 2
      // 4. route-state (depth 2) - handles its own grouping internally
      // 5. OR (depth 2) - has children at depth 3
      assert.strictEqual(
        this.consoleStub.groupCollapsed.callCount,
        5,
        "five groups collapsed (main + AND + route + route-state + OR)"
      );

      // Expected groupEnd calls should match groupCollapsed
      assert.strictEqual(
        this.consoleStub.groupEnd.callCount,
        5,
        "five groups ended (main + AND + route + route-state + OR)"
      );

      // Expected console.log calls:
      // 1. setting (depth 1) - no children
      // 2. queryParams[0] param-group (single key, logs directly)
      // 3. queryParams[1] param-group (single key, logs directly)
      // 4. route-state internal logs (params, queryParams)
      assert.true(
        this.consoleStub.log.callCount >= 3,
        "at least three log calls for leaf conditions"
      );
    });
  });

  module("hasActiveGroup", function () {
    test("returns false when no group active", function (assert) {
      assert.false(blockDebugLogger.hasActiveGroup());
    });

    test("returns true when group is active", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      assert.true(blockDebugLogger.hasActiveGroup());
      blockDebugLogger.endGroup(true);
    });
  });

  module("logRouteState", function () {
    test("displays checkmark when URL matches", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { urls: ["/latest"] },
        result: true,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/latest",
        expectedUrls: ["/latest"],
        excludeUrls: undefined,
        actualParams: {},
        actualQueryParams: {},
        depth: 1,
        result: true,
      });
      blockDebugLogger.endGroup(true);

      // Find the route-state groupCollapsed call (second one after main block)
      const routeStateCall = this.consoleStub.groupCollapsed
        .getCalls()
        .find((call) => call.args[0]?.includes("current URL"));
      assert.true(!!routeStateCall, "route-state groupCollapsed was called");
      assert.true(
        routeStateCall.args[0].includes("\u2713"),
        "displays checkmark for matching URL"
      );
    });

    test("displays X when URL does not match", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { urls: ["/c/**"] },
        result: false,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/latest",
        expectedUrls: ["/c/**"],
        excludeUrls: undefined,
        actualParams: {},
        actualQueryParams: {},
        depth: 1,
        result: false,
      });
      blockDebugLogger.endGroup(false);

      const routeStateCall = this.consoleStub.groupCollapsed
        .getCalls()
        .find((call) => call.args[0]?.includes("current URL"));
      assert.true(!!routeStateCall, "route-state groupCollapsed was called");
      assert.true(
        routeStateCall.args[0].includes("\u2717"),
        "displays X for non-matching URL"
      );
    });

    test("includes actual and expected URLs in output", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { urls: ["/c/**"] },
        result: false,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/latest",
        expectedUrls: ["/c/**"],
        excludeUrls: undefined,
        actualParams: {},
        actualQueryParams: {},
        depth: 1,
        result: false,
      });
      blockDebugLogger.endGroup(false);

      const routeStateCall = this.consoleStub.groupCollapsed
        .getCalls()
        .find((call) => call.args[0]?.includes("current URL"));
      // The last argument should be an object with actual and configured
      const dataArg = routeStateCall.args[routeStateCall.args.length - 1];
      assert.strictEqual(dataArg.actual, "/latest", "includes actual URL");
      assert.deepEqual(
        dataArg.configured,
        ["/c/**"],
        "includes configured URL patterns"
      );
    });

    test("includes excludeUrls in configured when using exclusion", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { excludeUrls: ["$HOMEPAGE"] },
        result: true,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/latest",
        expectedUrls: undefined,
        excludeUrls: ["$HOMEPAGE"],
        actualParams: {},
        actualQueryParams: {},
        depth: 1,
        result: true,
      });
      blockDebugLogger.endGroup(true);

      const routeStateCall = this.consoleStub.groupCollapsed
        .getCalls()
        .find((call) => call.args[0]?.includes("current URL"));
      const dataArg = routeStateCall.args[routeStateCall.args.length - 1];
      assert.strictEqual(dataArg.actual, "/latest", "includes actual URL");
      assert.deepEqual(
        dataArg.configured,
        { excludeUrls: ["$HOMEPAGE"] },
        "wraps excludeUrls in object for clarity"
      );
    });

    test("logs params and queryParams inside group", function (assert) {
      blockDebugLogger.startGroup("test-block", "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { urls: ["/t/**"], params: { id: 123 } },
        result: true,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/t/my-topic/123",
        expectedUrls: ["/t/**"],
        excludeUrls: undefined,
        actualParams: { id: 123, slug: "my-topic" },
        actualQueryParams: { page: "2" },
        depth: 1,
        result: true,
      });
      blockDebugLogger.endGroup(true);

      // Check that params and queryParams were logged
      const logCalls = this.consoleStub.log.getCalls();
      const paramsCall = logCalls.find((call) =>
        call.args[0]?.includes?.("params:")
      );
      const queryParamsCall = logCalls.find((call) =>
        call.args[0]?.includes?.("queryParams:")
      );

      assert.true(!!paramsCall, "params were logged");
      assert.true(!!queryParamsCall, "queryParams were logged");
    });
  });
});
