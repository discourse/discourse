import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import {
  removeValueFromArray,
  uniqueItemsFromArray,
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

  module("uniqueItemsFromArray()", function () {
    test("throws when input is not an array", function (assert) {
      assert.throws(
        () => uniqueItemsFromArray(null),
        /expects an array/,
        "null is rejected"
      );
      assert.throws(
        () => uniqueItemsFromArray(undefined),
        /expects an array/,
        "undefined is rejected"
      );
      assert.throws(
        () => uniqueItemsFromArray("not array"),
        /expects an array/,
        "string is rejected"
      );
      assert.throws(
        () => uniqueItemsFromArray({}),
        /expects an array/,
        "object is rejected"
      );
      assert.throws(
        () => uniqueItemsFromArray(123),
        /expects an array/,
        "number is rejected"
      );
    });

    test("returns a new empty array for empty input", function (assert) {
      const input = [];
      const result = uniqueItemsFromArray(input);

      assert.notStrictEqual(
        result,
        input,
        "returns a new array instance even for empty input"
      );
      assert.deepEqual(result, [], "result is empty");
    });

    test("deduplicates primitives by strict equality", function (assert) {
      const input = [1, 1, 2, 3, 2, 3, 4, 4, 4];
      const result = uniqueItemsFromArray(input);

      assert.deepEqual(result, [1, 2, 3, 4], "unique primitives retained");
      assert.notStrictEqual(
        result,
        input,
        "does not return original array reference"
      );
    });

    test("retains first occurrence order", function (assert) {
      const input = ["b", "a", "b", "c", "a", "d"];
      const result = uniqueItemsFromArray(input);

      assert.deepEqual(
        result,
        ["b", "a", "c", "d"],
        "order corresponds to first occurrences"
      );
    });

    test("uses identity for objects and symbols", function (assert) {
      const a1 = { id: 1 };
      const a2 = { id: 1 }; // different reference
      const b = { id: 2 };
      const s1 = Symbol("x");
      const s2 = Symbol("x");

      const input = [a1, a1, a2, b, s1, s1, s2];
      const result = uniqueItemsFromArray(input);

      assert.strictEqual(result[0], a1, "first a1 kept");
      assert.strictEqual(result[1], a2, "distinct object with same shape kept");
      assert.strictEqual(result[2], b, "b kept");
      assert.strictEqual(result[3], s1, "first symbol for x is kept");
      assert.strictEqual(result[4], s2, "second symbol for x is kept");

      assert.strictEqual(
        result.length,
        5,
        "duplicates by reference removed only"
      );
    });

    test("returns TrackedArray when input is TrackedArray", function (assert) {
      const tracked = new TrackedArray([1, 2, 2, 3, 3, 3]);
      const result = uniqueItemsFromArray(tracked);

      assert.true(result instanceof TrackedArray, "result is a TrackedArray");
      assert.deepEqual(Array.from(result), [1, 2, 3], "deduplicated correctly");
      assert.notStrictEqual(
        result,
        tracked,
        "returns a new TrackedArray instance"
      );
    });

    test("does not mutate the input array", function (assert) {
      const input = [1, 1, 2];
      const snapshot = input.slice();

      const result = uniqueItemsFromArray(input);

      assert.deepEqual(input, snapshot, "input remains unchanged");
      assert.deepEqual(result, [1, 2], "result is deduplicated");
    });

    test("handles heterogeneous arrays", function (assert) {
      const sym = Symbol("s");
      const input = [0, false, null, undefined, "", sym, 0, false, NaN, NaN];

      const result = uniqueItemsFromArray(input);

      // Set treats NaN as the same value, which is desired here
      assert.strictEqual(
        result.length,
        7,
        "expected number of unique elements"
      );
      assert.deepEqual(
        result.slice(0, 6),
        [0, false, null, undefined, "", sym],
        "first occurrences retained"
      );
      assert.true(Number.isNaN(result[6]), "NaN retained once");
    });

    test("treats NaN as a single unique value", function (assert) {
      const result = uniqueItemsFromArray([NaN, NaN, 1, NaN]);
      assert.strictEqual(result.length, 2, "NaN appears once among uniques");
      assert.true(Number.isNaN(result[0]), "NaN present");
    });

    // selector-based behavior

    test("selector: number index picks property by numeric key", function (assert) {
      const input = [
        ["a", 1],
        ["a", 2],
        ["b", 3],
        ["b", 4],
      ];
      const result = uniqueItemsFromArray(input, 0);
      assert.deepEqual(
        result,
        [
          ["a", 1],
          ["b", 3],
        ],
        "unique by index 0"
      );
    });

    test("selector: string key picks shallow property", function (assert) {
      const input = [
        { id: 1, name: "x" },
        { id: 1, name: "x2" },
        { id: 2, name: "y" },
      ];
      const result = uniqueItemsFromArray(input, "id");
      assert.strictEqual(result.length, 2, "two unique ids");
      assert.deepEqual(
        result.map((o) => o.name),
        ["x", "y"],
        "keeps first by id"
      );
    });

    test("selector: dotted path uses Ember get for nested property access", function (assert) {
      const input = [
        { user: { id: 10 } },
        { user: { id: 10 } },
        { user: { id: 11 } },
      ];
      const result = uniqueItemsFromArray(input, "user.id");
      assert.strictEqual(result.length, 2, "two unique nested ids");
      assert.deepEqual(
        result.map((o) => o.user.id),
        [10, 11],
        "keeps first by nested id"
      );
    });

    test("selector: function selector determines uniqueness", function (assert) {
      const input = [
        { id: 1, name: "Alice" },
        { id: 1, name: "Alice2" },
        { id: 2, name: "Bob" },
      ];
      const result = uniqueItemsFromArray(input, (o) => o.id);
      assert.strictEqual(result.length, 2, "two unique ids");
      assert.deepEqual(
        result.map((o) => o.name),
        ["Alice", "Bob"],
        "keeps first by function selector"
      );
    });
  });
});
