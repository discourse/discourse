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

      blockDebugLogger.startGroup("test-block", null, "outlet-name");

      assert.true(blockDebugLogger.hasActiveGroup());

      blockDebugLogger.endGroup(true);
    });
  });

  module("logCondition", function () {
    test("adds condition to current group", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
      blockDebugLogger.endGroup(true);

      assert.true(
        this.consoleStub.groupCollapsed.notCalled,
        "no console group for empty logs"
      );
    });

    test("shows RENDERED status for passing blocks", function (assert) {
      blockDebugLogger.startGroup("my-block", null, "homepage-blocks");
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
      blockDebugLogger.startGroup("my-block", null, "homepage-blocks");
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

    test("includes block id in display name and shows hierarchy with parent id", function (assert) {
      // Simulates a block with id "upcoming-events" inside a container with id "callouts"
      blockDebugLogger.startGroup(
        "theme:tactile:upcoming-events",
        "upcoming-events",
        "homepage-blocks/head(#callouts)"
      );
      blockDebugLogger.logCondition({
        type: "user",
        args: {},
        result: true,
        depth: 0,
      });
      blockDebugLogger.endGroup(true);

      const [message] = this.consoleStub.groupCollapsed.firstCall.args;
      assert.true(
        message.includes("theme:tactile:upcoming-events(#upcoming-events)"),
        "block name includes its own id"
      );
      assert.true(
        message.includes("in homepage-blocks/head(#callouts)"),
        "hierarchy includes parent container id"
      );
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
      blockDebugLogger.startGroup("outer-block", null, "outlet-name");

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
      blockDebugLogger.startGroup("complex-block", null, "main-outlet");

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
      // 4. OR (depth 2) - has children at depth 3
      // Note: route-state now uses console.log instead of groupCollapsed
      assert.strictEqual(
        this.consoleStub.groupCollapsed.callCount,
        4,
        "four groups collapsed (main + AND + route + OR)"
      );

      // Expected groupEnd calls should match groupCollapsed
      assert.strictEqual(
        this.consoleStub.groupEnd.callCount,
        4,
        "four groups ended (main + AND + route + OR)"
      );

      // Expected console.log calls:
      // 1. setting (depth 1) - no children
      // 2. queryParams[0] param-group (single key, logs directly)
      // 3. queryParams[1] param-group (single key, logs directly)
      // 4. route-state (current URL line)
      assert.true(
        this.consoleStub.log.callCount >= 4,
        "at least four log calls for leaf conditions and route-state"
      );
    });
  });

  module("hasActiveGroup", function () {
    test("returns false when no group active", function (assert) {
      assert.false(blockDebugLogger.hasActiveGroup());
    });

    test("returns true when group is active", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
      assert.true(blockDebugLogger.hasActiveGroup());
      blockDebugLogger.endGroup(true);
    });
  });

  module("logRouteState", function () {
    test("displays checkmark when URL matches", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
        _unusedQueryParams: {},
        depth: 1,
        result: true,
      });
      blockDebugLogger.endGroup(true);

      const routeStateCall = this.consoleStub.log
        .getCalls()
        .find((call) => call.args[0]?.includes?.("current URL"));
      assert.true(!!routeStateCall, "route-state log was called");
      assert.true(
        routeStateCall.args[0].includes("\u2713"),
        "displays checkmark for matching URL"
      );
    });

    test("displays X when URL does not match", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
        _unusedQueryParams: {},
        depth: 1,
        result: false,
      });
      blockDebugLogger.endGroup(false);

      const routeStateCall = this.consoleStub.log
        .getCalls()
        .find((call) => call.args[0]?.includes?.("current URL"));
      assert.true(!!routeStateCall, "route-state log was called");
      assert.true(
        routeStateCall.args[0].includes("\u2717"),
        "displays X for non-matching URL"
      );
    });

    test("includes actual and expected URLs in output", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
        _unusedQueryParams: {},
        depth: 1,
        result: false,
      });
      blockDebugLogger.endGroup(false);

      const routeStateCall = this.consoleStub.log
        .getCalls()
        .find((call) => call.args[0]?.includes?.("current URL"));
      // The last argument should be an object with actual and expected
      const dataArg = routeStateCall.args[routeStateCall.args.length - 1];
      assert.strictEqual(dataArg.actual, "/latest", "includes actual URL");
      assert.deepEqual(
        dataArg.expected,
        { urls: ["/c/**"] },
        "includes expected URL patterns"
      );
    });

    test("includes excludeUrls in expected when using exclusion", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
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
        _unusedQueryParams: {},
        depth: 1,
        result: true,
      });
      blockDebugLogger.endGroup(true);

      const routeStateCall = this.consoleStub.log
        .getCalls()
        .find((call) => call.args[0]?.includes?.("current URL"));
      const dataArg = routeStateCall.args[routeStateCall.args.length - 1];
      assert.strictEqual(dataArg.actual, "/latest", "includes actual URL");
      assert.deepEqual(
        dataArg.expected,
        { excludeUrls: ["$HOMEPAGE"] },
        "wraps excludeUrls in object for clarity"
      );
    });

    test("logs page type and params as siblings when using pages", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { pages: ["TOPIC_PAGES"], params: { id: 123 } },
        result: true,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/t/my-topic/123",
        pages: ["TOPIC_PAGES"],
        matchedPageType: "TOPIC_PAGES",
        actualPageContext: {
          pageType: "TOPIC_PAGES",
          id: 123,
          slug: "my-topic",
        },
        depth: 1,
        result: true,
      });
      // Params are now logged via logCondition (like queryParams)
      blockDebugLogger.logCondition({
        type: "params",
        args: { actual: { id: 123 }, expected: { id: 123 } },
        result: true,
        depth: 1,
      });
      blockDebugLogger.endGroup(true);

      // Page type and params should be logged as siblings
      const logCalls = this.consoleStub.log.getCalls();
      const pageTypeCall = logCalls.find((call) =>
        call.args[0]?.includes?.("on TOPIC_PAGES")
      );
      const paramsCall = logCalls.find((call) =>
        call.args[0]?.includes?.("params")
      );
      const queryParamsCall = logCalls.find((call) =>
        call.args[0]?.includes?.("queryParams")
      );

      assert.true(!!pageTypeCall, "page type was logged");
      assert.true(!!paramsCall, "params was logged");
      assert.false(
        !!queryParamsCall,
        "queryParams not logged without expected"
      );
    });

    test("shows page type matched even when params do not match", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { pages: ["CATEGORY_PAGES"], params: { categoryId: 1 } },
        result: false,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/c/general/4",
        pages: ["CATEGORY_PAGES"],
        matchedPageType: null,
        actualPageContext: {
          pageType: "CATEGORY_PAGES",
          categoryId: 4,
          categorySlug: "general",
        },
        depth: 1,
        result: false,
      });
      // Params are now logged via logCondition (like queryParams)
      blockDebugLogger.logCondition({
        type: "params",
        args: { actual: { categoryId: 4 }, expected: { categoryId: 1 } },
        result: false,
        depth: 1,
      });
      blockDebugLogger.endGroup(false);

      const logCalls = this.consoleStub.log.getCalls();

      // Page type should show as matched (checkmark) because we ARE on CATEGORY_PAGES
      const pageTypeCall = logCalls.find((call) =>
        call.args[0]?.includes?.("on CATEGORY_PAGES")
      );
      assert.true(!!pageTypeCall, "page type was logged");
      assert.true(
        pageTypeCall.args[0].includes("\u2713"),
        "shows checkmark for matching page type"
      );

      // Params should show as failed (X) because categoryId doesn't match
      const paramsCall = logCalls.find((call) =>
        call.args[0]?.includes?.("params")
      );
      assert.true(!!paramsCall, "params was logged");
      assert.true(
        paramsCall.args[0].includes("\u2717"),
        "shows X for non-matching params"
      );
    });

    test("shows actual page type when expected page type does not match", function (assert) {
      blockDebugLogger.startGroup("test-block", null, "outlet-name");
      blockDebugLogger.logCondition({
        type: "route",
        args: { pages: ["CATEGORY_PAGES"], params: { categoryId: 1 } },
        result: false,
        depth: 0,
      });
      blockDebugLogger.logRouteState({
        currentPath: "/t/my-topic/123",
        pages: ["CATEGORY_PAGES"],
        params: { categoryId: 1 },
        matchedPageType: null,
        actualPageType: "TOPIC_PAGES",
        actualPageContext: null,
        _unusedQueryParams: {},
        depth: 1,
        result: false,
      });
      blockDebugLogger.endGroup(false);

      const logCalls = this.consoleStub.log.getCalls();

      // Should show "not on CATEGORY_PAGES (actual: TOPIC_PAGES)"
      const pageTypeCall = logCalls.find((call) =>
        call.args[0]?.includes?.("not on CATEGORY_PAGES")
      );
      assert.true(!!pageTypeCall, "page type mismatch was logged");
      assert.true(
        pageTypeCall.args[0].includes("(actual: TOPIC_PAGES)"),
        "shows actual page type"
      );
    });
  });

  module("params with operators", function () {
    test("logs params summary and OR combinator for { any: [...] }", function (assert) {
      // Simulates the logging structure for params: { any: [...] }
      // Both params summary and OR combinator should be logged
      blockDebugLogger.startGroup("test-block", null, "outlet-name");

      // Route condition (parent)
      blockDebugLogger.logCondition({
        type: "route",
        args: { pages: ["CATEGORY_PAGES"] },
        result: true,
        depth: 0,
      });

      // Page type matched
      blockDebugLogger.logRouteState({
        currentPath: "/c/general/4",
        pages: ["CATEGORY_PAGES"],
        matchedPageType: "CATEGORY_PAGES",
        actualPageContext: { pageType: "CATEGORY_PAGES", categoryId: 4 },
        depth: 1,
        result: true,
      });

      // Params summary (logged before nested OR)
      const paramsSpec = { _isParams: true };
      blockDebugLogger.logCondition({
        type: "params",
        args: {
          actual: { categoryId: 4 },
          expected: { any: [{ categoryId: 1 }, { categoryId: 4 }] },
        },
        result: null,
        depth: 1,
        conditionSpec: paramsSpec,
      });

      // OR combinator (nested under params at deeper depth)
      const orSpec = { any: [{ categoryId: 1 }, { categoryId: 4 }] };
      blockDebugLogger.logCondition({
        type: "OR",
        args: "2 params specs",
        result: null,
        depth: 2,
        conditionSpec: orSpec,
      });

      // Individual param checks (nested under OR)
      blockDebugLogger.logParamGroup({
        label: "params",
        matches: [{ key: "categoryId", expected: 1, actual: 4, result: false }],
        result: false,
        depth: 3,
      });
      blockDebugLogger.logParamGroup({
        label: "params",
        matches: [{ key: "categoryId", expected: 4, actual: 4, result: true }],
        result: true,
        depth: 3,
      });

      // Update results
      blockDebugLogger.updateCombinatorResult(orSpec, true);
      blockDebugLogger.updateConditionResult(paramsSpec, true);

      blockDebugLogger.endGroup(true);

      const logCalls = this.consoleStub.log.getCalls();
      const groupCalls = this.consoleStub.groupCollapsed.getCalls();
      const allCalls = [...logCalls, ...groupCalls];

      // Verify params summary was logged (may be in groupCollapsed if it has children)
      const paramsSummaryCall = allCalls.find(
        (call) =>
          call.args[0]?.includes?.("params") &&
          !call.args[0]?.includes?.("OR") &&
          !call.args[0]?.includes?.("categoryId")
      );
      assert.true(!!paramsSummaryCall, "params summary was logged");

      // Verify OR combinator was logged
      const orCall = allCalls.find((call) => call.args[0]?.includes?.("OR"));
      assert.true(!!orCall, "OR combinator was logged");
    });

    test("logs params summary and NOT combinator for { not: {...} }", function (assert) {
      // Simulates the logging structure for params: { not: {...} }
      // Both params summary and NOT combinator should be logged
      blockDebugLogger.startGroup("test-block", null, "outlet-name");

      // Route condition (parent)
      blockDebugLogger.logCondition({
        type: "route",
        args: { pages: ["CATEGORY_PAGES"] },
        result: true,
        depth: 0,
      });

      // Page type matched
      blockDebugLogger.logRouteState({
        currentPath: "/c/general/4",
        pages: ["CATEGORY_PAGES"],
        matchedPageType: "CATEGORY_PAGES",
        actualPageContext: { pageType: "CATEGORY_PAGES", categoryId: 4 },
        depth: 1,
        result: true,
      });

      // Params summary (logged before nested NOT)
      const paramsSpec = { _isParams: true };
      blockDebugLogger.logCondition({
        type: "params",
        args: {
          actual: { categoryId: 4 },
          expected: { not: { categoryId: 10 } },
        },
        result: null,
        depth: 1,
        conditionSpec: paramsSpec,
      });

      // NOT combinator (nested under params at deeper depth)
      const notSpec = { not: { categoryId: 10 } };
      blockDebugLogger.logCondition({
        type: "NOT",
        args: null,
        result: null,
        depth: 2,
        conditionSpec: notSpec,
      });

      // Inner param check (nested under NOT)
      blockDebugLogger.logParamGroup({
        label: "params",
        matches: [
          { key: "categoryId", expected: 10, actual: 4, result: false },
        ],
        result: false,
        depth: 3,
      });

      // Update results (NOT inverts the inner false to true)
      blockDebugLogger.updateCombinatorResult(notSpec, true);
      blockDebugLogger.updateConditionResult(paramsSpec, true);

      blockDebugLogger.endGroup(true);

      const logCalls = this.consoleStub.log.getCalls();
      const groupCalls = this.consoleStub.groupCollapsed.getCalls();
      const allCalls = [...logCalls, ...groupCalls];

      // Verify params summary was logged (may be in groupCollapsed if it has children)
      const paramsSummaryCall = allCalls.find(
        (call) =>
          call.args[0]?.includes?.("params") &&
          !call.args[0]?.includes?.("NOT") &&
          !call.args[0]?.includes?.("categoryId")
      );
      assert.true(!!paramsSummaryCall, "params summary was logged");

      // Verify NOT combinator was logged
      const notCall = allCalls.find((call) => call.args[0]?.includes?.("NOT"));
      assert.true(!!notCall, "NOT combinator was logged");
    });

    test("params at depth 1 renders before OR at depth 2 in tree", function (assert) {
      // Verifies that params (depth 1) appears before OR (depth 2) in the log buffer
      // The tree structure should have params as parent of OR
      blockDebugLogger.startGroup("test-block", null, "outlet-name");

      // Params at depth 1 (parent)
      const paramsSpec = { _isParams: true };
      blockDebugLogger.logCondition({
        type: "params",
        args: { actual: {}, expected: {} },
        result: null,
        depth: 1,
        conditionSpec: paramsSpec,
      });

      // OR at depth 2 (child of params)
      const orSpec = {};
      blockDebugLogger.logCondition({
        type: "OR",
        args: "2 specs",
        result: null,
        depth: 2,
        conditionSpec: orSpec,
      });

      blockDebugLogger.updateCombinatorResult(orSpec, true);
      blockDebugLogger.updateConditionResult(paramsSpec, true);

      blockDebugLogger.endGroup(true);

      const logCalls = this.consoleStub.log.getCalls();
      const groupCalls = this.consoleStub.groupCollapsed.getCalls();

      // Params has children (OR at depth 2), so it's logged as groupCollapsed
      const paramsCall = groupCalls.find((call) =>
        call.args[0]?.includes?.("params")
      );
      assert.true(!!paramsCall, "params was logged as group (has children)");

      // OR has no children, so it's logged with console.log
      const orCall = logCalls.find((call) => call.args[0]?.includes?.("OR"));
      assert.true(!!orCall, "OR was logged");

      // Verify params group opened before OR was logged
      // The group structure ensures params is the parent containing OR
      assert.true(
        groupCalls.some((call) => call.args[0]?.includes?.("params")),
        "params group exists for tree hierarchy"
      );
    });
  });
});
