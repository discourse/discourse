import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import { removeObject } from "discourse/lib/array-tools";

module("Unit | Lib | array-tools", function () {
  module("removeObject()", function () {
    test("removes all occurrences of a primitive value from a plain array", function (assert) {
      const input = [1, 2, 3, 2, 4, 2, 5];
      const result = removeObject(input, 2);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [1, 3, 4, 5], "removes all matching entries");
    });

    test("does nothing if the value is not found", function (assert) {
      const input = [1, 2, 3];
      const result = removeObject(input, 99);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [1, 2, 3], "array remains unchanged");
    });

    test("works with an empty array", function (assert) {
      const input = [];
      const result = removeObject(input, "x");

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(result, [], "still empty");
    });

    test("removes only strictly-equal values", function (assert) {
      const obj = { a: 1 };
      const sameShape = { a: 1 };
      const input = [obj, sameShape, obj];

      const result = removeObject(input, obj);

      assert.strictEqual(result, input, "returns the same array reference");
      assert.deepEqual(
        result,
        [sameShape],
        "removes only the instances strictly equal to the target"
      );
    });

    test("removes all occurrences from a TrackedArray", function (assert) {
      const tracked = new TrackedArray([1, 2, 3, 2, 4]);
      const result = removeObject(tracked, 2);

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

      let result = removeObject(input, 0);
      assert.deepEqual(
        result,
        [false, null, undefined, "", sym, false],
        "removes all 0 but keeps falsy non-zero values"
      );

      result = removeObject(result, false);
      assert.deepEqual(
        result,
        [null, undefined, "", sym],
        "removes all false but keeps other falsy values"
      );

      result = removeObject(result, sym);
      assert.deepEqual(
        result,
        [null, undefined, ""],
        "removes symbol by identity"
      );
    });

    test("idempotent if called repeatedly with same value", function (assert) {
      const input = [1, 1, 2, 3, 1];

      const once = removeObject(input, 1);
      assert.deepEqual(once, [2, 3], "first removal removes all occurrences");

      const twice = removeObject(once, 1);
      assert.strictEqual(twice, once, "same reference returned");
      assert.deepEqual(twice, [2, 3], "second removal is a no-op");
    });
  });
});
