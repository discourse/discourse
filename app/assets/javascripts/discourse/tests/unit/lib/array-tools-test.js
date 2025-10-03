import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import {
  removeValueFromArray,
  removeValuesFromArray,
} from "discourse/lib/array-tools";

module("Unit | Lib | array-tools", function () {
  module("removeValueFromArray()", function () {
    test("removes all occurrences of a primitive value from a plain array", function (assert) {
      const input = [1, 2, 3, 2, 4, 2, 5];
      const result = removeValueFromArray(input, 2);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [1, 3, 4, 5], "removes all matching entries");
    });

    test("does nothing if the value is not found", function (assert) {
      const input = [1, 2, 3];
      const result = removeValueFromArray(input, 99);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [1, 2, 3], "array remains unchanged");
    });

    test("works with an empty array", function (assert) {
      const input = [];
      const result = removeValueFromArray(input, "x");

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [], "still empty");
    });

    test("removes only strictly-equal values", function (assert) {
      const obj = { a: 1 };
      const sameShape = { a: 1 };
      const input = [obj, sameShape, obj];

      const result = removeValueFromArray(input, obj);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(
        result,
        [sameShape],
        "removes only the instances strictly equal to the target"
      );
    });

    test("removes all occurrences from a TrackedArray", function (assert) {
      const tracked = new TrackedArray([1, 2, 3, 2, 4]);
      const result = removeValueFromArray(tracked, 2);

      assert.strictEqual(
        result,
        tracked,
        "returns the same TrackedArray instance"
      );
      assert.deepEqual(
        Array.from(result),
        [1, 3, 4],
        "removes all matching entries"
      );
    });

    test("handles heterogeneous arrays", function (assert) {
      const sym = Symbol("s");
      const input = [0, false, null, undefined, "", sym, 0, false];

      let result = removeValueFromArray(input, 0);
      assert.deepEqual(
        result,
        [false, null, undefined, "", sym, false],
        "removes all 0 but keeps falsy non-zero values"
      );

      result = removeValueFromArray(result, false);
      assert.deepEqual(
        result,
        [null, undefined, "", sym],
        "removes all false but keeps other falsy values"
      );

      result = removeValueFromArray(result, sym);
      assert.deepEqual(
        result,
        [null, undefined, ""],
        "removes symbol by identity"
      );
    });

    test("idempotent if called repeatedly with same value", function (assert) {
      const input = [1, 1, 2, 3, 1];

      const once = removeValueFromArray(input, 1);
      assert.deepEqual(once, [2, 3], "first removal removes all occurrences");

      const twice = removeValueFromArray(once, 1);
      assert.strictEqual(twice, once, "same reference returned");
      assert.deepEqual(twice, [2, 3], "second removal is a no-op");
    });
  });

  module("removeValuesFromArray()", function () {
    test("removes multiple primitive values from a plain array", function (assert) {
      const input = [1, 2, 3, 2, 4, 5, 3, 6];
      const result = removeValuesFromArray(input, [2, 3]);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [1, 4, 5, 6], "removes all listed values");
    });

    test("works when values contains duplicates", function (assert) {
      const input = [1, 2, 3, 2, 3, 4];
      const result = removeValuesFromArray(input, [2, 2, 3]);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [1, 4], "duplicates in values don't matter");
    });

    test("does nothing when values list is empty", function (assert) {
      const input = [1, 2, 3];
      const result = removeValuesFromArray(input, []);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [1, 2, 3], "array remains unchanged");
    });

    test("removes by strict equality including objects and symbols", function (assert) {
      const a = { id: 1 };
      const b = { id: 2 };
      const dupA = { id: 1 };
      const sym1 = Symbol("x");
      const sym2 = Symbol("x");

      const input = [a, b, dupA, sym1, sym2, a];
      const result = removeValuesFromArray(input, [a, sym2]);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(
        result,
        [b, dupA, sym1],
        "removes only strictly-equal instances"
      );
    });

    test("works with TrackedArray and maintains same instance", function (assert) {
      const tracked = new TrackedArray([1, 2, 3, 4, 5, 2, 4]);
      const result = removeValuesFromArray(tracked, [2, 4]);

      assert.strictEqual(result, tracked, "same TrackedArray instance");
      assert.deepEqual(Array.from(result), [1, 3, 5], "values removed");
    });

    test("handles heterogeneous arrays and order of removal", function (assert) {
      const sym = Symbol("s");
      const input = [0, false, null, undefined, "", sym, 0, false, "x"];

      const result = removeValuesFromArray(input, [false, 0, sym]);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(
        result,
        [null, undefined, "", "x"],
        "removes all specified values regardless of order"
      );
    });

    test("idempotent when called repeatedly with same values list", function (assert) {
      const input = [1, 1, 2, 3, 1];

      const once = removeValuesFromArray(input, [1, 2]);
      assert.deepEqual(once, [3], "first call removes 1 and 2");

      const twice = removeValuesFromArray(once, [1, 2]);
      assert.strictEqual(twice, once, "same reference returned");
      assert.deepEqual(twice, [3], "second call is a no-op");
    });
  });
});
