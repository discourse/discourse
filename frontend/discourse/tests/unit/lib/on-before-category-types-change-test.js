import { module, test } from "qunit";
import {
  registerOnBeforeCategoryTypesChange,
  resetOnBeforeCategoryTypesChange,
  runOnBeforeCategoryTypesChange,
} from "discourse/lib/on-before-category-types-change";

const ctx = {
  nextTypes: [],
  previousTypes: [],
  category: {},
  form: {},
  transientData: undefined,
};

module("Unit | lib | on-before-category-types-change", function (hooks) {
  hooks.beforeEach(function () {
    resetOnBeforeCategoryTypesChange();
  });

  test("no callbacks means allow", async function (assert) {
    assert.true(
      await runOnBeforeCategoryTypesChange(ctx),
      "empty registry allows"
    );
  });

  test("callback returning false vetoes", async function (assert) {
    registerOnBeforeCategoryTypesChange(() => false);
    assert.false(await runOnBeforeCategoryTypesChange(ctx));
  });

  test("callback returning true allows", async function (assert) {
    registerOnBeforeCategoryTypesChange(() => true);
    assert.true(await runOnBeforeCategoryTypesChange(ctx));
  });

  test("stops at first false and does not run following callbacks", async function (assert) {
    let firstCount = 0;
    let secondCount = 0;
    registerOnBeforeCategoryTypesChange(() => {
      firstCount += 1;
      return false;
    });
    registerOnBeforeCategoryTypesChange(() => {
      secondCount += 1;
      return true;
    });
    assert.false(await runOnBeforeCategoryTypesChange(ctx));
    assert.strictEqual(firstCount, 1, "first callback runs once");
    assert.strictEqual(secondCount, 0, "second callback not invoked");
  });

  test("runs in order and all must allow", async function (assert) {
    const order = [];
    registerOnBeforeCategoryTypesChange(() => {
      order.push(1);
      return true;
    });
    registerOnBeforeCategoryTypesChange(() => {
      order.push(2);
      return true;
    });
    assert.true(await runOnBeforeCategoryTypesChange(ctx));
    assert.deepEqual(order, [1, 2]);
  });

  test("async callback that resolves true allows", async function (assert) {
    registerOnBeforeCategoryTypesChange(async () => true);
    assert.true(await runOnBeforeCategoryTypesChange(ctx));
  });

  test("async callback that resolves false vetoes", async function (assert) {
    registerOnBeforeCategoryTypesChange(async () => false);
    assert.false(await runOnBeforeCategoryTypesChange(ctx));
  });

  test("throws in callback rethrows in tests and vetoes in production path", async function (assert) {
    registerOnBeforeCategoryTypesChange(() => {
      throw new Error("guard failed");
    });
    await assert.rejects(
      runOnBeforeCategoryTypesChange(ctx),
      /guard failed/,
      "rethrows in test environment"
    );
  });

  test("passes the same context object to the callback", async function (assert) {
    const localCtx = { a: 1, nextTypes: [] };
    registerOnBeforeCategoryTypesChange((c) => {
      assert.strictEqual(c, localCtx, "context is the same object reference");
      return true;
    });
    assert.true(await runOnBeforeCategoryTypesChange(localCtx));
  });
});
