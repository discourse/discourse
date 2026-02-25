import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  getNextArgNumber,
  logArgToConsole,
  resetArgCounter,
} from "discourse/static/dev-tools/lib/console-logger";

module("Unit | Lib | dev-tools/console-logger", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    // Reset counter before each test
    resetArgCounter();

    // Stub console methods
    this.consoleStub = {
      log: sinon.stub(console, "log"),
      warn: sinon.stub(console, "warn"),
    };

    // Track window properties we set
    this.windowVars = [];
  });

  hooks.afterEach(function () {
    // Restore console
    this.consoleStub.log.restore();
    this.consoleStub.warn.restore();

    // Clean up window variables
    for (const varName of this.windowVars) {
      delete window[varName];
    }
  });

  module("resetArgCounter", function () {
    test("resets counter to 1", function (assert) {
      // Increment counter a few times
      logArgToConsole({ key: "test1", value: 1 });
      this.windowVars.push("arg1");
      logArgToConsole({ key: "test2", value: 2 });
      this.windowVars.push("arg2");

      assert.strictEqual(getNextArgNumber(), 3);

      resetArgCounter();

      assert.strictEqual(getNextArgNumber(), 1);
    });
  });

  module("getNextArgNumber", function () {
    test("returns current counter value", function (assert) {
      assert.strictEqual(getNextArgNumber(), 1);
    });

    test("does not increment counter", function (assert) {
      assert.strictEqual(getNextArgNumber(), 1);
      assert.strictEqual(getNextArgNumber(), 1);
      assert.strictEqual(getNextArgNumber(), 1);
    });
  });

  module("logArgToConsole", function () {
    test("returns assigned variable name", function (assert) {
      const varName = logArgToConsole({ key: "test", value: 42 });
      this.windowVars.push(varName);

      assert.strictEqual(varName, "arg1");
    });

    test("increments counter for each call", function (assert) {
      const first = logArgToConsole({ key: "a", value: 1 });
      this.windowVars.push(first);
      const second = logArgToConsole({ key: "b", value: 2 });
      this.windowVars.push(second);
      const third = logArgToConsole({ key: "c", value: 3 });
      this.windowVars.push(third);

      assert.strictEqual(first, "arg1");
      assert.strictEqual(second, "arg2");
      assert.strictEqual(third, "arg3");
    });

    test("stores value in window global", function (assert) {
      const testValue = { foo: "bar" };
      const varName = logArgToConsole({ key: "test", value: testValue });
      this.windowVars.push(varName);

      assert.strictEqual(window[varName], testValue);
    });

    test("logs to console with styled output", function (assert) {
      logArgToConsole({ key: "myKey", value: 123 });
      this.windowVars.push("arg1");

      assert.true(this.consoleStub.log.calledOnce);

      const args = this.consoleStub.log.firstCall.args;
      assert.true(args[0].includes("myKey"));
      assert.true(args[0].includes("arg1"));
    });

    test("includes prefix when provided", function (assert) {
      logArgToConsole({ key: "test", value: 1, prefix: "plugin outlet" });
      this.windowVars.push("arg1");

      const args = this.consoleStub.log.firstCall.args;
      assert.true(args[0].includes("[plugin outlet]"));
    });

    test("does not include prefix brackets when not provided", function (assert) {
      logArgToConsole({ key: "test", value: 1 });
      this.windowVars.push("arg1");

      const args = this.consoleStub.log.firstCall.args;
      assert.false(args[0].includes("["));
    });

    test("includes value as last argument for inspection", function (assert) {
      const testValue = { complex: "object" };
      logArgToConsole({ key: "test", value: testValue });
      this.windowVars.push("arg1");

      const args = this.consoleStub.log.firstCall.args;
      assert.strictEqual(args[args.length - 1], testValue);
    });

    test("warns when overwriting existing global", function (assert) {
      // Set up existing global
      window.arg1 = "existing";
      this.windowVars.push("arg1");

      logArgToConsole({ key: "test", value: "new" });

      assert.true(this.consoleStub.warn.calledOnce);
      assert.true(
        this.consoleStub.warn.firstCall.args[0].includes("Overwriting")
      );
    });

    test("does not warn for fresh variable names", function (assert) {
      logArgToConsole({ key: "test", value: 1 });
      this.windowVars.push("arg1");

      assert.false(this.consoleStub.warn.called);
    });
  });
});
