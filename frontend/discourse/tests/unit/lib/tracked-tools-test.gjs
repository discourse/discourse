import { cached, tracked } from "@glimmer/tracking";
import { run } from "@ember/runloop";
import { settled } from "@ember/test-helpers";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { module, test } from "qunit";
import {
  dedupeTracked,
  DeferredTrackedSet,
  enumerateTrackedKeys,
  enumerateTrackedValues,
  trackedArray,
} from "discourse/lib/tracked-tools";

module("Unit | tracked-tools", function () {
  test("@dedupeTracked", async function (assert) {
    class Pet {
      initialsEvaluatedCount = 0;

      @dedupeTracked name;

      @cached
      get initials() {
        this.initialsEvaluatedCount++;
        return this.name
          ?.split(" ")
          .map((n) => n[0])
          .join("");
      }
    }

    const pet = new Pet();
    pet.name = "Scooby Doo";

    assert.strictEqual(pet.initials, "SD", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      1,
      "Initials getter evaluated once"
    );

    pet.name = "Scooby Doo";
    assert.strictEqual(pet.initials, "SD", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      1,
      "Initials getter not re-evaluated"
    );

    pet.name = "Fluffy";
    assert.strictEqual(pet.initials, "F", "Initials are correct");
    assert.strictEqual(
      pet.initialsEvaluatedCount,
      2,
      "Initials getter re-evaluated"
    );
  });

  test("DeferredTrackedSet", async function (assert) {
    class Player {
      evaluationsCount = 0;

      letters = new DeferredTrackedSet();

      @cached
      get score() {
        this.evaluationsCount++;
        return this.letters.size;
      }
    }

    const player = new Player();
    assert.strictEqual(player.score, 0, "score is correct");
    assert.strictEqual(player.evaluationsCount, 1, "getter evaluated once");

    run(() => {
      player.letters.add("a");

      assert.strictEqual(player.score, 0, "score does not change");
      assert.strictEqual(
        player.evaluationsCount,
        1,
        "getter does not evaluate"
      );

      player.letters.add("b");
      player.letters.add("c");

      assert.strictEqual(player.score, 0, "score still does not change");
      assert.strictEqual(
        player.evaluationsCount,
        1,
        "getter still does not evaluate"
      );
    });
    await settled();

    assert.strictEqual(player.score, 3, "score is correct");
    assert.strictEqual(player.evaluationsCount, 2, "getter evaluated again");

    run(() => {
      player.letters.add("d");
    });
    await settled();

    assert.strictEqual(player.score, 4, "score is correct");
    assert.strictEqual(player.evaluationsCount, 3, "getter evaluated again");

    run(() => {
      player.letters.add("e");

      assert.strictEqual(player.score, 4, "score is correct");
      assert.strictEqual(
        player.evaluationsCount,
        3,
        "getter does not evaluate"
      );

      player.letters.add("f");
    });
    await settled();

    assert.strictEqual(player.score, 6, "score is correct");
    assert.strictEqual(player.evaluationsCount, 4, "getter evaluated");
    assert.deepEqual([...player.letters], ["a", "b", "c", "d", "e", "f"]);
  });

  module("@trackedArray", function () {
    test("initializes with an array", function (assert) {
      class TestClass {
        @trackedArray items = ["a", "b", "c"];
      }

      const instance = new TestClass();
      assert.true(
        instance.items instanceof TrackedArray,
        "should wrap initial array in TrackedArray"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["a", "b", "c"],
        "should preserve array contents"
      );
    });

    test("accepts null as initial value", function (assert) {
      class TestClass {
        @trackedArray items = null;
      }

      const instance = new TestClass();
      assert.strictEqual(
        instance.items,
        null,
        "should allow null as initial value"
      );
    });

    test("accepts undefined as initial value", function (assert) {
      class TestClass {
        @trackedArray items;
      }

      const instance = new TestClass();
      assert.strictEqual(
        instance.items,
        undefined,
        "should allow undefined as initial value"
      );
    });

    test("handles setting regular arrays", function (assert) {
      class TestClass {
        @trackedArray items;
      }

      const instance = new TestClass();
      instance.items = ["x", "y", "z"];

      assert.true(
        instance.items instanceof TrackedArray,
        "should wrap new array in TrackedArray"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["x", "y", "z"],
        "should contain new array values"
      );
    });

    test("accepts TrackedArray instances directly", function (assert) {
      class TestClass {
        @trackedArray items = [];
      }

      const instance = new TestClass();
      const trackedArr = new TrackedArray(["foo", "bar"]);
      instance.items = trackedArr;

      assert.strictEqual(
        instance.items,
        trackedArr,
        "should use the provided TrackedArray instance"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["foo", "bar"],
        "should contain correct values"
      );
    });

    test("allows setting to null", function (assert) {
      class TestClass {
        @trackedArray items = ["initial"];
      }

      const instance = new TestClass();
      instance.items = null;

      assert.strictEqual(instance.items, null, "should allow setting to null");
    });

    test("allows setting to undefined", function (assert) {
      class TestClass {
        @trackedArray items = ["initial"];
      }

      const instance = new TestClass();
      instance.items = undefined;

      assert.strictEqual(
        instance.items,
        undefined,
        "should allow setting to undefined"
      );
    });

    test("throws error for invalid values", function (assert) {
      class TestClass {
        @trackedArray items = [];
      }

      const instance = new TestClass();

      assert.throws(
        () => {
          instance.items = "not an array";
        },
        /Expected an array, TrackedArray, null, or undefined, got/,
        "should throw for strings"
      );

      assert.throws(
        () => {
          instance.items = 42;
        },
        /Expected an array, TrackedArray, null, or undefined, got/,
        "should throw for numbers"
      );

      assert.throws(
        () => {
          instance.items = {};
        },
        /Expected an array, TrackedArray, null, or undefined, got/,
        "should throw for plain objects"
      );
    });

    test("tracks changes to array contents", function (assert) {
      class TestClass {
        evaluationsCount = 0;
        @trackedArray items = ["a"];

        @cached
        get itemCount() {
          this.evaluationsCount++;
          return this.items.length;
        }

        addItem(item) {
          this.items = [...this.items, item];
        }
      }

      const instance = new TestClass();
      assert.strictEqual(instance.itemCount, 1, "initial count is correct");
      assert.strictEqual(instance.evaluationsCount, 1, "getter evaluated once");

      assert.strictEqual(
        instance.itemCount,
        1,
        "count not updated when reading the value again."
      );
      assert.strictEqual(
        instance.evaluationsCount,
        1,
        "getter wasn't evaluated again"
      );

      instance.addItem("b"); // Adding same item
      assert.strictEqual(
        instance.itemCount,
        2,
        "count updated after duplicate add"
      );
      assert.strictEqual(
        instance.evaluationsCount,
        2,
        "getter re-evaluated after change"
      );

      assert.deepEqual(
        Array.from(instance.items),
        ["a", "b"],
        "array contains correct items"
      );
    });
  });

  module("enumerateTrackedKeys", function () {
    test("returns tracked property keys from an object", function (assert) {
      class Person {
        @tracked name = "Alice";
        @tracked age = 30;
        regularProp = "not tracked";
      }

      const instance = new Person();
      const result = enumerateTrackedKeys(instance);

      assert.deepEqual(
        result,
        ["name", "age"],
        "returns only tracked property keys"
      );
      assert.false(
        result.includes("regularProp"),
        "non-tracked property is not included"
      );
    });

    test("returns empty array for null or undefined", function (assert) {
      const resultNull = enumerateTrackedKeys(null);
      const resultUndefined = enumerateTrackedKeys(undefined);

      assert.deepEqual(resultNull, [], "returns empty array for null");
      assert.deepEqual(
        resultUndefined,
        [],
        "returns empty array for undefined"
      );
    });

    test("returns empty array for objects without tracked properties", function (assert) {
      class SimpleClass {
        prop1 = "value1";
        prop2 = "value2";
      }

      const instance = new SimpleClass();
      const result = enumerateTrackedKeys(instance);

      assert.deepEqual(
        result,
        [],
        "returns empty array for non-tracked properties"
      );
    });

    test("handles objects with only tracked properties", function (assert) {
      class AllTracked {
        @tracked first = "one";
        @tracked second = "two";
        @tracked third = "three";
      }

      const instance = new AllTracked();
      const result = enumerateTrackedKeys(instance);

      assert.deepEqual(
        result.sort(),
        ["first", "second", "third"].sort(),
        "returns all tracked property keys"
      );
      assert.strictEqual(result.length, 3, "returns correct number of keys");
    });

    test("includes @dedupeTracked properties", function (assert) {
      class TestClass {
        @tracked normalTracked = "normal";
        @dedupeTracked dedupedTracked = "deduped";
        regularProp = "regular";
      }

      const instance = new TestClass();
      const result = enumerateTrackedKeys(instance);

      assert.true(
        result.includes("normalTracked"),
        "includes @tracked property"
      );
      assert.true(
        result.includes("dedupedTracked"),
        "includes @dedupeTracked property"
      );
      assert.false(result.includes("regularProp"), "excludes regular property");
    });

    test("includes @trackedArray properties", function (assert) {
      class TestClass {
        @tracked name = "test";
        @trackedArray items = ["a", "b", "c"];
        regularProp = "regular";
      }

      const instance = new TestClass();
      const result = enumerateTrackedKeys(instance);

      assert.true(result.includes("name"), "includes @tracked property");
      assert.true(result.includes("items"), "includes @trackedArray property");
      assert.false(result.includes("regularProp"), "excludes regular property");
    });

    test("handles inherited tracked properties", function (assert) {
      class Parent {
        @tracked parentProp = "parent";
      }

      class Child extends Parent {
        @tracked childProp = "child";
      }

      const instance = new Child();
      const result = enumerateTrackedKeys(instance);

      assert.true(
        result.includes("parentProp"),
        "includes parent tracked property"
      );
      assert.true(
        result.includes("childProp"),
        "includes child tracked property"
      );
      assert.strictEqual(
        result.length,
        2,
        "includes both parent and child properties"
      );
    });

    test("handles multi-level inheritance", function (assert) {
      class GrandParent {
        @tracked grandProp = "grand";
      }

      class Parent extends GrandParent {
        @tracked parentProp = "parent";
      }

      class Child extends Parent {
        @tracked childProp = "child";
      }

      const instance = new Child();
      const result = enumerateTrackedKeys(instance);

      assert.true(
        result.includes("grandProp"),
        "includes grandparent property"
      );
      assert.true(result.includes("parentProp"), "includes parent property");
      assert.true(result.includes("childProp"), "includes child property");
      assert.strictEqual(result.length, 3, "includes all inherited properties");
    });

    test("returns keys regardless of current property values", function (assert) {
      class TestClass {
        @tracked nullProp = null;
        @tracked undefinedProp = undefined;
        @tracked stringProp = "value";
      }

      const instance = new TestClass();
      const result = enumerateTrackedKeys(instance);

      assert.true(
        result.includes("nullProp"),
        "includes property with null value"
      );
      assert.true(
        result.includes("undefinedProp"),
        "includes property with undefined value"
      );
      assert.true(
        result.includes("stringProp"),
        "includes property with string value"
      );
      assert.strictEqual(
        result.length,
        3,
        "returns all keys regardless of values"
      );
    });

    test("handles objects with various tracked value types", function (assert) {
      class MixedTypes {
        @tracked string = "text";
        @tracked number = 42;
        @tracked boolean = true;
        @tracked object = { nested: "value" };
        @tracked array = [1, 2, 3];
      }

      const instance = new MixedTypes();
      const result = enumerateTrackedKeys(instance);

      assert.deepEqual(
        result.sort(),
        ["array", "boolean", "number", "object", "string"].sort(),
        "returns keys for all value types"
      );
    });
  });

  module("enumerateTrackedValues", function () {
    test("returns tracked properties from an object", function (assert) {
      class Person {
        @tracked name = "Alice";
        @tracked age = 30;
        regularProp = "not tracked";
      }

      const instance = new Person();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(result.name, "Alice", "tracked name is included");
      assert.strictEqual(result.age, 30, "tracked age is included");
      assert.strictEqual(
        result.regularProp,
        undefined,
        "non-tracked property is not included"
      );
      assert.deepEqual(
        Object.keys(result),
        ["name", "age"],
        "only tracked properties are enumerated"
      );
    });

    test("returns empty object for null or undefined", function (assert) {
      const resultNull = enumerateTrackedValues(null);
      const resultUndefined = enumerateTrackedValues(undefined);

      assert.deepEqual(
        resultNull,
        Object.create(null),
        "returns empty object for null"
      );
      assert.deepEqual(
        resultUndefined,
        Object.create(null),
        "returns empty object for undefined"
      );
    });

    test("returns empty object for objects without tracked properties", function (assert) {
      class SimpleClass {
        prop1 = "value1";
        prop2 = "value2";
      }

      const instance = new SimpleClass();
      const result = enumerateTrackedValues(instance);

      assert.deepEqual(
        Object.keys(result),
        [],
        "returns no keys for non-tracked properties"
      );
    });

    test("handles objects with only tracked properties", function (assert) {
      class AllTracked {
        @tracked first = "one";
        @tracked second = "two";
        @tracked third = "three";
      }

      const instance = new AllTracked();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(result.first, "one");
      assert.strictEqual(result.second, "two");
      assert.strictEqual(result.third, "three");
      assert.strictEqual(Object.keys(result).length, 3);
    });

    test("includes @dedupeTracked properties", function (assert) {
      class TestClass {
        @tracked normalTracked = "normal";
        @dedupeTracked dedupedTracked = "deduped";
        regularProp = "regular";
      }

      const instance = new TestClass();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(result.normalTracked, "normal");
      assert.strictEqual(result.dedupedTracked, "deduped");
      assert.strictEqual(result.regularProp, undefined);
    });

    test("includes @trackedArray properties", function (assert) {
      class TestClass {
        @tracked name = "test";
        @trackedArray items = ["a", "b", "c"];
        regularProp = "regular";
      }

      const instance = new TestClass();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(result.name, "test");
      assert.true(result.items instanceof TrackedArray);
      assert.deepEqual(Array.from(result.items), ["a", "b", "c"]);
      assert.strictEqual(result.regularProp, undefined);
    });

    test("handles inherited tracked properties", function (assert) {
      class Parent {
        @tracked parentProp = "parent";
      }

      class Child extends Parent {
        @tracked childProp = "child";
      }

      const instance = new Child();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(
        result.parentProp,
        "parent",
        "includes parent tracked property"
      );
      assert.strictEqual(
        result.childProp,
        "child",
        "includes child tracked property"
      );
      assert.strictEqual(
        Object.keys(result).length,
        2,
        "includes both parent and child properties"
      );
    });

    test("handles multi-level inheritance", function (assert) {
      class GrandParent {
        @tracked grandProp = "grand";
      }

      class Parent extends GrandParent {
        @tracked parentProp = "parent";
      }

      class Child extends Parent {
        @tracked childProp = "child";
      }

      const instance = new Child();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(result.grandProp, "grand");
      assert.strictEqual(result.parentProp, "parent");
      assert.strictEqual(result.childProp, "child");
      assert.strictEqual(Object.keys(result).length, 3);
    });

    test("reflects current property values", function (assert) {
      class Counter {
        @tracked count = 0;
      }

      const instance = new Counter();
      assert.strictEqual(
        enumerateTrackedValues(instance).count,
        0,
        "initial value is 0"
      );

      instance.count = 5;
      assert.strictEqual(
        enumerateTrackedValues(instance).count,
        5,
        "updated value is reflected"
      );

      instance.count = 100;
      assert.strictEqual(
        enumerateTrackedValues(instance).count,
        100,
        "further updates are reflected"
      );
    });

    test("handles tracked properties with null/undefined values", function (assert) {
      class TestClass {
        @tracked nullProp = null;
        @tracked undefinedProp = undefined;
        @tracked stringProp = "value";
      }

      const instance = new TestClass();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(result.nullProp, null, "null value is preserved");
      assert.strictEqual(
        result.undefinedProp,
        undefined,
        "undefined value is preserved"
      );
      assert.strictEqual(result.stringProp, "value", "string value is correct");
      assert.true("nullProp" in result, "null property key exists in result");
      assert.true(
        "undefinedProp" in result,
        "undefined property key exists in result"
      );
    });

    test("handles objects with various tracked value types", function (assert) {
      class MixedTypes {
        @tracked string = "text";
        @tracked number = 42;
        @tracked boolean = true;
        @tracked object = { nested: "value" };
        @tracked array = [1, 2, 3];
      }

      const instance = new MixedTypes();
      const result = enumerateTrackedValues(instance);

      assert.strictEqual(result.string, "text");
      assert.strictEqual(result.number, 42);
      assert.true(result.boolean);
      assert.deepEqual(result.object, { nested: "value" });
      assert.deepEqual(result.array, [1, 2, 3]);
    });
  });
});
