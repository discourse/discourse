import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { blockDebugLogger } from "discourse/lib/blocks/debug-logger";

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

      assert.true(
        this.consoleStub.groupCollapsed.calledOnce,
        "console.groupCollapsed called"
      );
      assert.strictEqual(
        this.consoleStub.log.callCount,
        2,
        "two conditions logged"
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
        args: { routes: ["index"] },
        result: true,
        depth: 2,
      });
      blockDebugLogger.updateCombinatorResult(true, 1);
      blockDebugLogger.updateCombinatorResult(true, 0);

      blockDebugLogger.endGroup(true);

      assert.strictEqual(
        this.consoleStub.log.callCount,
        4,
        "four conditions logged"
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
});
