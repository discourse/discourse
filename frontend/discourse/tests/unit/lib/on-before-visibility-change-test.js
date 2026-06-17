import { module, test } from "qunit";
import {
  registerOnBeforeVisibilityChange,
  resetOnBeforeVisibilityChange,
  runOnBeforeVisibilityChange,
} from "discourse/lib/on-before-visibility-change";

const ctx = {
  nextVisibility: "group_restricted",
  previousVisibility: "public",
  category: {},
  form: {},
  transientData: undefined,
};

module("Unit | lib | on-before-visibility-change", function (hooks) {
  hooks.beforeEach(function () {
    resetOnBeforeVisibilityChange();
  });

  test("no callbacks means allow", async function (assert) {
    assert.true(
      await runOnBeforeVisibilityChange(ctx),
      "empty registry allows"
    );
  });

  test("callback returning false vetoes", async function (assert) {
    registerOnBeforeVisibilityChange(() => false);
    assert.false(await runOnBeforeVisibilityChange(ctx));
  });

  test("callback returning true allows", async function (assert) {
    registerOnBeforeVisibilityChange(() => true);
    assert.true(await runOnBeforeVisibilityChange(ctx));
  });

  test("stops at first false and does not run following callbacks", async function (assert) {
    let firstCount = 0;
    let secondCount = 0;
    registerOnBeforeVisibilityChange(() => {
      firstCount += 1;
      return false;
    });
    registerOnBeforeVisibilityChange(() => {
      secondCount += 1;
      return true;
    });
    assert.false(await runOnBeforeVisibilityChange(ctx));
    assert.strictEqual(firstCount, 1, "first callback runs once");
    assert.strictEqual(secondCount, 0, "second callback not invoked");
  });

  test("runs in order and all must allow", async function (assert) {
    const order = [];
    registerOnBeforeVisibilityChange(() => {
      order.push(1);
      return true;
    });
    registerOnBeforeVisibilityChange(() => {
      order.push(2);
      return true;
    });
    assert.true(await runOnBeforeVisibilityChange(ctx));
    assert.deepEqual(order, [1, 2]);
  });

  test("async callback that resolves true allows", async function (assert) {
    registerOnBeforeVisibilityChange(async () => true);
    assert.true(await runOnBeforeVisibilityChange(ctx));
  });

  test("async callback that resolves false vetoes", async function (assert) {
    registerOnBeforeVisibilityChange(async () => false);
    assert.false(await runOnBeforeVisibilityChange(ctx));
  });

  test("throws in callback rethrows in tests and vetoes in production path", async function (assert) {
    registerOnBeforeVisibilityChange(() => {
      throw new Error("guard failed");
    });
    await assert.rejects(
      runOnBeforeVisibilityChange(ctx),
      /guard failed/,
      "rethrows in test environment"
    );
  });

  test("passes the same context object to the callback", async function (assert) {
    const localCtx = { a: 1, nextVisibility: "group_restricted" };
    registerOnBeforeVisibilityChange((c) => {
      assert.strictEqual(c, localCtx, "context is the same object reference");
      return true;
    });
    assert.true(await runOnBeforeVisibilityChange(localCtx));
  });
});
