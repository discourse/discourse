import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import {
  addUniqueValuesToArray,
  addUniqueValueToArray,
  removeValueFromArray,
  removeValuesFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";

module("Unit | Lib | array-tools", function () {
  module("addUniqueValueToArray()", function () {
    test("adds a value when not present and returns same reference", function (assert) {
      const arr = [1, 2];
      const result = addUniqueValueToArray(arr, 3);

      assert.strictEqual(result, arr, "returns the same array reference");
      assert.deepEqual(arr, [1, 2, 3], "value appended");
    });

    test("does not add duplicate values", function (assert) {
      const arr = [1, 2, 3];
      const result = addUniqueValueToArray(arr, 2);

      assert.strictEqual(result, arr, "returns the same array reference");
      assert.deepEqual(arr, [1, 2, 3], "no duplicate added");
    });

    test("works with objects by reference identity", function (assert) {
      const a = { id: 1 };
      const b = { id: 1 };
      const arr = [a];

      addUniqueValueToArray(arr, b);
      assert.deepEqual(arr, [a, b], "different references are both kept");

      addUniqueValueToArray(arr, a);
      assert.deepEqual(arr, [a, b], "existing reference not duplicated");
    });

    test("works with TrackedArray and preserves instance", function (assert) {
      const tracked = new TrackedArray([1]);
      const result = addUniqueValueToArray(tracked, 2);

      assert.strictEqual(
        result,
        tracked,
        "same TrackedArray instance returned"
      );
      assert.deepEqual(Array.from(tracked), [1, 2], "value added");
    });

    test("handles heterogeneous arrays and NaN", function (assert) {
      const sym = Symbol("s");
      const arr = [0, false, null, undefined, "", sym, NaN];

      addUniqueValueToArray(arr, 0);
      addUniqueValueToArray(arr, false);
      addUniqueValueToArray(arr, null);
      addUniqueValueToArray(arr, undefined);
      addUniqueValueToArray(arr, "");
      addUniqueValueToArray(arr, sym);
      addUniqueValueToArray(arr, NaN); // includes treats NaN as true

      assert.deepEqual(
        arr.slice(0, 7),
        [0, false, null, undefined, "", sym, NaN],
        "no duplicates for existing heterogeneous values including NaN"
      );
      addUniqueValueToArray(arr, "x");
      assert.strictEqual(
        arr[arr.length - 1],
        "x",
        "new distinct value appended"
      );
    });

    test("adds object with selector based on property value", function (assert) {
      const arr = [{ id: 1, name: "Alice" }];
      addUniqueValueToArray(arr, { id: 2, name: "Bob" }, (item) => item.id);

      assert.strictEqual(arr.length, 2, "object with different id added");
      assert.deepEqual(
        arr.map((o) => o.name),
        ["Alice", "Bob"],
        "both objects present"
      );
    });

    test("does not add object with selector when value already exists", function (assert) {
      const arr = [
        { id: 1, name: "Alice" },
        { id: 2, name: "Bob" },
      ];
      addUniqueValueToArray(arr, { id: 1, name: "Alice2" }, (item) => item.id);

      assert.strictEqual(arr.length, 2, "duplicate id not added");
      assert.deepEqual(
        arr.map((o) => o.name),
        ["Alice", "Bob"],
        "original objects unchanged"
      );
    });

    test("selector compares the transformed value", function (assert) {
      const arr = [{ value: "apple" }, { value: "banana" }];
      addUniqueValueToArray(arr, { value: "APPLE" }, (item) =>
        item.value.toLowerCase()
      );

      assert.strictEqual(arr.length, 2, "case-insensitive duplicate not added");

      addUniqueValueToArray(arr, { value: "CHERRY" }, (item) =>
        item.value.toLowerCase()
      );

      assert.strictEqual(arr.length, 3, "unique value added");
      assert.strictEqual(arr[2].value, "CHERRY", "new value appended");
    });
  });

  module("addUniqueValuesToArray()", function () {
    test("adds multiple values only when not present", function (assert) {
      const arr = [1, 3];
      addUniqueValuesToArray(arr, [1, 2, 3, 4]);

      assert.deepEqual(arr, [1, 3, 2, 4], "only missing values appended");
    });

    test("no-op when all values already present", function (assert) {
      const arr = ["a", "b"];
      const result = addUniqueValuesToArray(arr, ["a", "b"]);

      assert.strictEqual(result, undefined, "function returns void");
      assert.deepEqual(arr, ["a", "b"], "array remains unchanged");
    });

    test("works with empty values list", function (assert) {
      const arr = [1, 2, 3];
      addUniqueValuesToArray(arr, []);

      assert.deepEqual(arr, [1, 2, 3], "unchanged");
    });

    test("throws when target is not an array", function (assert) {
      assert.throws(
        () => addUniqueValuesToArray(null, [1]),
        /'target' must be an array/,
        "null target rejected"
      );
      assert.throws(
        () => addUniqueValuesToArray({}, [1]),
        /'target' must be an array/,
        "object target rejected"
      );
    });

    test("throws when values is not an array", function (assert) {
      assert.throws(
        () => addUniqueValuesToArray([], null),
        /'values' must be an array/,
        "null values rejected"
      );
      assert.throws(
        () => addUniqueValuesToArray([], "x"),
        /'values' must be an array/,
        "string values rejected"
      );
    });

    test("preserves TrackedArray instance and appends only missing entries", function (assert) {
      const tracked = new TrackedArray([1, 2]);
      const result = addUniqueValuesToArray(tracked, [2, 3, 4, 3]);

      assert.strictEqual(result, undefined, "function returns void");
      assert.true(tracked instanceof TrackedArray, "still a TrackedArray");
      assert.deepEqual(
        Array.from(tracked),
        [1, 2, 3, 4],
        "only unique additions appended"
      );
    });

    test("idempotent across repeated calls with same values", function (assert) {
      const arr = [1];
      addUniqueValuesToArray(arr, [1, 2]);
      assert.deepEqual(arr, [1, 2], "first call adds 2");

      addUniqueValuesToArray(arr, [1, 2]);
      assert.deepEqual(arr, [1, 2], "second call no-ops");
    });

    test("adds multiple objects with selector based on property value", function (assert) {
      const arr = [{ id: 1, name: "Alice" }];
      addUniqueValuesToArray(
        arr,
        [
          { id: 2, name: "Bob" },
          { id: 3, name: "Charlie" },
          { id: 4, name: "David" },
        ],
        (item) => item.id
      );

      assert.strictEqual(arr.length, 4, "three new objects added");
      assert.deepEqual(
        arr.map((o) => o.name),
        ["Alice", "Bob", "Charlie", "David"],
        "all unique objects present"
      );
    });

    test("does not add objects with selector when values already exist", function (assert) {
      const arr = [
        { id: 1, name: "Alice" },
        { id: 2, name: "Bob" },
      ];
      addUniqueValuesToArray(
        arr,
        [
          { id: 1, name: "Alice2" },
          { id: 3, name: "Charlie" },
          { id: 2, name: "Bob2" },
        ],
        (item) => item.id
      );

      assert.strictEqual(arr.length, 3, "only unique id added");
      assert.deepEqual(
        arr.map((o) => o.name),
        ["Alice", "Bob", "Charlie"],
        "duplicate ids not added, new id added"
      );
    });

    test("selector compares transformed values across multiple additions", function (assert) {
      const arr = [{ value: "apple" }];
      addUniqueValuesToArray(
        arr,
        [
          { value: "APPLE" },
          { value: "banana" },
          { value: "BANANA" },
          { value: "cherry" },
        ],
        (item) => item.value.toLowerCase()
      );

      assert.strictEqual(
        arr.length,
        3,
        "only case-insensitive unique values added"
      );
      assert.deepEqual(
        arr.map((o) => o.value),
        ["apple", "banana", "cherry"],
        "first occurrence of each unique value kept"
      );
    });
  });

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
