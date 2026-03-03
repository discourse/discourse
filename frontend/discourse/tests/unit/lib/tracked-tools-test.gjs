import { cached, tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { run } from "@ember/runloop";
import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  autoTrackedArray,
  dedupeTracked,
  DeferredTrackedSet,
  enumerateTrackedEntries,
  enumerateTrackedKeys,
  isTrackedArray,
  trackedObjectWithComputedSupport,
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

  module("isTrackedArray", function () {
    test("returns true for trackedArray() instances", function (assert) {
      assert.true(isTrackedArray(trackedArray()), "empty tracked array");
      assert.true(
        isTrackedArray(trackedArray([1, 2, 3])),
        "tracked array with data"
      );
    });

    test("returns false for plain arrays", function (assert) {
      assert.false(isTrackedArray([]), "empty array");
      assert.false(isTrackedArray([1, 2, 3]), "array with data");
    });

    test("returns false for null, undefined, and non-array values", function (assert) {
      assert.false(isTrackedArray(null), "null");
      assert.false(isTrackedArray(undefined), "undefined");
      assert.false(isTrackedArray(42), "number");
      assert.false(isTrackedArray("string"), "string");
      assert.false(isTrackedArray({}), "plain object");
    });
  });

  module("@autoTrackedArray", function () {
    test("initializes with an array", function (assert) {
      class TestClass {
        @autoTrackedArray items = ["a", "b", "c"];
      }

      const instance = new TestClass();
      assert.true(
        isTrackedArray(instance.items),
        "should wrap initial array in tracked array"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["a", "b", "c"],
        "should preserve array contents"
      );
    });

    test("accepts null as initial value", function (assert) {
      class TestClass {
        @autoTrackedArray items = null;
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
        @autoTrackedArray items;
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
        @autoTrackedArray items;
      }

      const instance = new TestClass();
      instance.items = ["x", "y", "z"];

      assert.true(
        isTrackedArray(instance.items),
        "should wrap new array in tracked array"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["x", "y", "z"],
        "should contain new array values"
      );
    });

    test("accepts tracked array instances directly", function (assert) {
      class TestClass {
        @autoTrackedArray items = [];
      }

      const instance = new TestClass();
      const trackedArr = trackedArray(["foo", "bar"]);
      instance.items = trackedArr;

      assert.strictEqual(
        instance.items,
        trackedArr,
        "should use the provided tracked array instance"
      );
      assert.deepEqual(
        Array.from(instance.items),
        ["foo", "bar"],
        "should contain correct values"
      );
    });

    test("allows setting to null", function (assert) {
      class TestClass {
        @autoTrackedArray items = ["initial"];
      }

      const instance = new TestClass();
      instance.items = null;

      assert.strictEqual(instance.items, null, "should allow setting to null");
    });

    test("allows setting to undefined", function (assert) {
      class TestClass {
        @autoTrackedArray items = ["initial"];
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
        @autoTrackedArray items = [];
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
        @autoTrackedArray items = ["a"];

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

    test("invalidates @computed when TrackedArray contents are mutated", function (assert) {
      class TestClass {
        computeCount = 0;
        @autoTrackedArray items = ["a"];

        @computed("items")
        get itemCount() {
          this.computeCount++;
          return this.items?.length ?? 0;
        }
      }

      const instance = new TestClass();
      assert.strictEqual(instance.itemCount, 1, "initial count is correct");
      assert.strictEqual(instance.computeCount, 1, "computed evaluated once");

      // In-place mutation via push
      instance.items.push("b");
      assert.strictEqual(
        instance.itemCount,
        2,
        "computed invalidated after push"
      );
      assert.strictEqual(instance.computeCount, 2, "computed re-evaluated");

      // In-place mutation via splice
      instance.items.splice(0, 1);
      assert.strictEqual(
        instance.itemCount,
        1,
        "computed invalidated after splice"
      );
      assert.strictEqual(instance.computeCount, 3, "computed re-evaluated");

      // Reference change still works
      instance.items = ["x", "y", "z"];
      assert.strictEqual(
        instance.itemCount,
        3,
        "computed invalidated after reference change"
      );
      assert.strictEqual(instance.computeCount, 4, "computed re-evaluated");
    });

    test("invalidates @computed with .[] dependent key on mutations", function (assert) {
      class TestClass {
        computeCount = 0;
        @autoTrackedArray items = [];

        @computed("items.[]")
        get itemCount() {
          this.computeCount++;
          return this.items?.length ?? 0;
        }
      }

      const instance = new TestClass();
      assert.strictEqual(instance.itemCount, 0, "initial count is correct");
      assert.strictEqual(instance.computeCount, 1, "computed evaluated once");

      instance.items.push("a");
      assert.strictEqual(
        instance.itemCount,
        1,
        "computed invalidated after push"
      );
      assert.strictEqual(instance.computeCount, 2, "computed re-evaluated");
    });

    test("@computed works with null @autoTrackedArray value", function (assert) {
      class TestClass {
        @autoTrackedArray items = null;

        @computed("items")
        get hasItems() {
          return this.items != null && this.items.length > 0;
        }
      }

      const instance = new TestClass();
      assert.false(instance.hasItems, "no items when null");

      instance.items = ["a"];
      assert.true(instance.hasItems, "has items after setting array");
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

    test("includes @autoTrackedArray properties", function (assert) {
      class TestClass {
        @tracked name = "test";
        @autoTrackedArray items = ["a", "b", "c"];
        regularProp = "regular";
      }

      const instance = new TestClass();
      const result = enumerateTrackedKeys(instance);

      assert.true(result.includes("name"), "includes @tracked property");
      assert.true(
        result.includes("items"),
        "includes @autoTrackedArray property"
      );
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

  module("enumerateTrackedEntries", function () {
    test("returns tracked property entries from an object", function (assert) {
      class Person {
        @tracked name = "Alice";
        @tracked age = 30;
        regularProp = "not tracked";
      }

      const instance = new Person();
      const result = enumerateTrackedEntries(instance);

      assert.deepEqual(
        result,
        [
          ["name", "Alice"],
          ["age", 30],
        ],
        "returns entries for tracked properties"
      );
    });

    test("returns empty array for null or undefined", function (assert) {
      const resultNull = enumerateTrackedEntries(null);
      const resultUndefined = enumerateTrackedEntries(undefined);

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
      const result = enumerateTrackedEntries(instance);

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
      const result = enumerateTrackedEntries(instance);

      assert.strictEqual(result.length, 3, "returns three entries");
      const obj = Object.fromEntries(result);
      assert.strictEqual(obj.first, "one");
      assert.strictEqual(obj.second, "two");
      assert.strictEqual(obj.third, "three");
    });

    test("includes @dedupeTracked properties", function (assert) {
      class TestClass {
        @tracked normalTracked = "normal";
        @dedupeTracked dedupedTracked = "deduped";
        regularProp = "regular";
      }

      const instance = new TestClass();
      const result = enumerateTrackedEntries(instance);

      const obj = Object.fromEntries(result);
      assert.strictEqual(obj.normalTracked, "normal");
      assert.strictEqual(obj.dedupedTracked, "deduped");
      assert.strictEqual(obj.regularProp, undefined);
    });

    test("includes @autoTrackedArray properties", function (assert) {
      class TestClass {
        @tracked name = "test";
        @autoTrackedArray items = ["a", "b", "c"];
        regularProp = "regular";
      }

      const instance = new TestClass();
      const result = enumerateTrackedEntries(instance);

      const obj = Object.fromEntries(result);
      assert.strictEqual(obj.name, "test");
      assert.true(isTrackedArray(obj.items));
      assert.deepEqual(Array.from(obj.items), ["a", "b", "c"]);
      assert.strictEqual(obj.regularProp, undefined);
    });

    test("handles inherited tracked properties", function (assert) {
      class Parent {
        @tracked parentProp = "parent";
      }

      class Child extends Parent {
        @tracked childProp = "child";
      }

      const instance = new Child();
      const result = enumerateTrackedEntries(instance);

      assert.strictEqual(
        result.length,
        2,
        "includes both parent and child properties"
      );
      const obj = Object.fromEntries(result);
      assert.strictEqual(
        obj.parentProp,
        "parent",
        "includes parent tracked property"
      );
      assert.strictEqual(
        obj.childProp,
        "child",
        "includes child tracked property"
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
      const result = enumerateTrackedEntries(instance);

      assert.strictEqual(result.length, 3);
      const obj = Object.fromEntries(result);
      assert.strictEqual(obj.grandProp, "grand");
      assert.strictEqual(obj.parentProp, "parent");
      assert.strictEqual(obj.childProp, "child");
    });

    test("reflects current property values", function (assert) {
      class Counter {
        @tracked count = 0;
      }

      const instance = new Counter();
      assert.strictEqual(
        Object.fromEntries(enumerateTrackedEntries(instance)).count,
        0,
        "initial value is 0"
      );

      instance.count = 5;
      assert.strictEqual(
        Object.fromEntries(enumerateTrackedEntries(instance)).count,
        5,
        "updated value is reflected"
      );

      instance.count = 100;
      assert.strictEqual(
        Object.fromEntries(enumerateTrackedEntries(instance)).count,
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
      const result = enumerateTrackedEntries(instance);

      const obj = Object.fromEntries(result);
      assert.strictEqual(obj.nullProp, null, "null value is preserved");
      assert.strictEqual(
        obj.undefinedProp,
        undefined,
        "undefined value is preserved"
      );
      assert.strictEqual(obj.stringProp, "value", "string value is correct");
      assert.true("nullProp" in obj, "null property key exists in result");
      assert.true(
        "undefinedProp" in obj,
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
      const result = enumerateTrackedEntries(instance);

      const obj = Object.fromEntries(result);
      assert.strictEqual(obj.string, "text");
      assert.strictEqual(obj.number, 42);
      assert.true(obj.boolean);
      assert.deepEqual(obj.object, { nested: "value" });
      assert.deepEqual(obj.array, [1, 2, 3]);
    });

    test("can be converted to object with Object.fromEntries", function (assert) {
      class TestClass {
        @tracked firstName = "Alice";
        @tracked lastName = "Smith";
      }

      const instance = new TestClass();
      const entries = enumerateTrackedEntries(instance);
      const obj = Object.fromEntries(entries);

      assert.deepEqual(
        obj,
        { firstName: "Alice", lastName: "Smith" },
        "entries can be converted back to object"
      );
    });
  });

  module("trackedObjectWithComputedSupport", function () {
    test("basic get and set", function (assert) {
      const obj = trackedObjectWithComputedSupport({ name: "Alice", age: 30 });

      assert.strictEqual(obj.name, "Alice");
      assert.strictEqual(obj.age, 30);

      obj.name = "Bob";
      obj.age = 25;

      assert.strictEqual(obj.name, "Bob");
      assert.strictEqual(obj.age, 25);
    });

    test("autotracking with @cached getter", function (assert) {
      const obj = trackedObjectWithComputedSupport({ count: 0 });
      let evaluations = 0;

      class Reader {
        @cached
        get doubleCount() {
          evaluations++;
          return obj.count * 2;
        }
      }

      const reader = new Reader();
      assert.strictEqual(reader.doubleCount, 0);
      assert.strictEqual(evaluations, 1);

      obj.count = 5;
      assert.strictEqual(reader.doubleCount, 10);
      assert.strictEqual(evaluations, 2);

      // Reading again without changes should not re-evaluate
      assert.strictEqual(reader.doubleCount, 10);
      assert.strictEqual(evaluations, 2);
    });

    test("@computed chain observation recomputes on property change", function (assert) {
      const obj = trackedObjectWithComputedSupport({ title: "original" });
      let computeCount = 0;

      class Observer {
        obj = obj;

        @computed("obj.title")
        get display() {
          computeCount++;
          return `Title: ${this.obj.title}`;
        }
      }

      const observer = new Observer();
      assert.strictEqual(observer.display, "Title: original");
      assert.strictEqual(computeCount, 1);

      // Changing a property observed by @computed should trigger recomputation
      obj.title = "updated";
      assert.strictEqual(observer.display, "Title: updated");
      assert.strictEqual(computeCount, 2);
    });

    test("no mandatory setter assertion on property assignment", function (assert) {
      const obj = trackedObjectWithComputedSupport({ title: "original" });

      class Observer {
        obj = obj;

        @computed("obj.title")
        get display() {
          return this.obj.title;
        }
      }

      const observer = new Observer();

      // Force chain tag setup by reading the @computed property
      assert.strictEqual(observer.display, "original");

      // This assignment would throw a mandatory setter assertion without the fix,
      // because setupMandatorySetter would have installed a throwing setter on the
      // Proxy target's data descriptor. If the fix doesn't work, this line throws.
      obj.title = "updated";

      assert.strictEqual(obj.title, "updated");
      assert.strictEqual(observer.display, "updated");
    });

    test("Object.keys returns expected keys", function (assert) {
      const obj = trackedObjectWithComputedSupport({ a: 1, b: 2, c: 3 });
      assert.deepEqual(Object.keys(obj).sort(), ["a", "b", "c"]);
    });

    test("new properties can be added", function (assert) {
      const obj = trackedObjectWithComputedSupport({ existing: true });

      obj.newProp = "hello";
      assert.strictEqual(obj.newProp, "hello");
      assert.true(obj.existing);
    });

    test("delete operator works", function (assert) {
      const obj = trackedObjectWithComputedSupport({ a: 1, b: 2 });

      delete obj.a;
      assert.strictEqual(obj.a, undefined);
      assert.deepEqual(Object.keys(obj), ["b"]);
    });
  });
});
