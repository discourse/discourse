import { getOwner } from "@ember/owner";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import ArrayLikeObject from "discourse/lib/array-like-object";
import { withPluginApi } from "discourse/lib/plugin-api";

module("Unit | lib | ArrayLikeObject", function (hooks) {
  setupTest(hooks);

  test("constructs with default values", function (assert) {
    let obj = new ArrayLikeObject();
    assert.true(
      obj instanceof ArrayLikeObject,
      "returns an ArrayLikeObject instance"
    );
    assert.strictEqual(obj.length, 0, "empty by default");
  });

  test("accepts initial items", function (assert) {
    let obj = new ArrayLikeObject([1, 2, 3]);
    assert.deepEqual([...obj], [1, 2, 3], "contains initial items");
    assert.strictEqual(obj.length, 3, "length is correct");
  });

  test("accepts TrackedArray as items", function (assert) {
    let arr = new TrackedArray([4, 5]);
    let obj = new ArrayLikeObject(arr);
    assert.strictEqual(obj[0], 4);
    assert.strictEqual(obj[1], 5);
    assert.strictEqual(obj.length, 2);
  });

  test("assigns custom properties", function (assert) {
    let obj = new ArrayLikeObject([1], { foo: "bar" });
    assert.strictEqual(obj.foo, "bar", "property is assigned");
    obj.foo = "baz";
    assert.strictEqual(obj.foo, "baz", "property is settable");
  });

  test("throws if items is not an array", function (assert) {
    assert.throws(
      () => new ArrayLikeObject("not an array"),
      /items must be an array/
    );
  });

  test("array methods work", function (assert) {
    let obj = new ArrayLikeObject([1, 2]);
    obj.push(3);
    assert.deepEqual([...obj], [1, 2, 3]);
    assert.strictEqual(obj.pop(), 3);
    assert.deepEqual([...obj], [1, 2]);

    // map
    obj = new ArrayLikeObject([1, 2, 3, 4]);
    assert.deepEqual(
      obj.map((x) => x * 2),
      [2, 4, 6, 8],
      "map works"
    );

    // filter
    assert.deepEqual(
      obj.filter((x) => x % 2 === 0),
      [2, 4],
      "filter works"
    );

    // find
    assert.strictEqual(
      obj.find((x) => x > 2),
      3,
      "find works"
    );

    // findIndex
    assert.strictEqual(
      obj.findIndex((x) => x === 3),
      2,
      "findIndex works"
    );

    // some
    assert.true(
      obj.some((x) => x === 2),
      "some works"
    );

    // every
    assert.true(
      obj.every((x) => x > 0),
      "every works"
    );
    assert.false(
      obj.every((x) => x > 2),
      "every works for false"
    );

    // reduce
    assert.strictEqual(
      obj.reduce((a, b) => a + b, 0),
      10,
      "reduce works"
    );

    // slice
    assert.deepEqual(obj.slice(1, 3), [2, 3], "slice works");

    // concat
    assert.deepEqual(obj.concat([5, 6]), [1, 2, 3, 4, 5, 6], "concat works");

    // reverse
    assert.deepEqual(obj.slice().reverse(), [4, 3, 2, 1], "reverse works");

    // includes
    assert.true(obj.includes(3), "includes works");
    assert.false(obj.includes(99), "includes works for false");

    // at
    assert.strictEqual(obj.at(0), 1, "at(0) works");
    assert.strictEqual(obj.at(-1), 4, "at(-1) works");
  });

  test("instance properties take precedence over array", function (assert) {
    class CustomArrayLike extends ArrayLikeObject {
      get first() {
        return "custom";
      }
    }
    let obj = new CustomArrayLike([1, 2]);
    assert.strictEqual(obj.first, "custom");
  });

  test("subclassing works", function (assert) {
    class CustomArrayLike extends ArrayLikeObject {
      customField = "foo";
      #bar = 42;

      get bar() {
        return this.#bar;
      }

      set bar(val) {
        this.#bar = val;
      }

      get firstPlusBar() {
        return (this[0] || 0) + this.bar;
      }

      customMethod() {
        return this.length * 10;
      }
    }
    let obj = new CustomArrayLike([5, 6, 7]);

    // Custom field
    assert.strictEqual(obj.customField, "foo", "custom field is present");

    // Getter
    assert.strictEqual(obj.bar, 42, "getter works");

    // Setter
    obj.bar = 100;
    assert.strictEqual(obj.bar, 100, "setter works");

    // Custom method
    assert.strictEqual(obj.customMethod(), 30, "custom method works");

    // Computed getter using array and custom field
    assert.strictEqual(
      obj.firstPlusBar,
      105,
      "getter using array and field works"
    );

    // Array-like behavior
    assert.strictEqual(obj.length, 3, "length is correct");
    assert.strictEqual(obj[0], 5, "index access works");
    obj.push(8);
    assert.deepEqual([...obj], [5, 6, 7, 8], "push works");
    assert.strictEqual(obj.pop(), 8, "pop works");
    assert.deepEqual(
      obj.map((x) => x * 2),
      [10, 12, 14],
      "map works"
    );
  });

  test("multiple levels of inheritance work as expected", function (assert) {
    class BaseArrayLike extends ArrayLikeObject {
      baseField = "base";

      get baseValue() {
        return this.baseField + this.length;
      }
    }
    class MidArrayLike extends BaseArrayLike {
      midField = "mid";

      get midValue() {
        return this.midField + (this[0] || 0);
      }
    }
    class FinalArrayLike extends MidArrayLike {
      finalField = "final";

      get finalValue() {
        return this.finalField + (this[1] || 0);
      }

      customMethod() {
        return this.baseValue + this.midValue + this.finalValue;
      }
    }
    let obj = new FinalArrayLike([10, 20]);

    // Base class field and getter
    assert.strictEqual(obj.baseField, "base", "base field present");
    assert.strictEqual(obj.baseValue, "base2", "base getter works");

    // Mid class field and getter
    assert.strictEqual(obj.midField, "mid", "mid field present");
    assert.strictEqual(obj.midValue, "mid10", "mid getter works");

    // Final class field and getter
    assert.strictEqual(obj.finalField, "final", "final field present");
    assert.strictEqual(obj.finalValue, "final20", "final getter works");

    // Custom method using all levels
    assert.strictEqual(
      obj.customMethod(),
      "base2mid10final20",
      "custom method combines all levels"
    );

    // Array-like behavior
    assert.strictEqual(obj.length, 2, "length is correct");
    assert.strictEqual(obj[0], 10, "index access works");
    obj.push(30);
    assert.deepEqual([...obj], [10, 20, 30], "push works");
    assert.strictEqual(obj.pop(), 30, "pop works");
    assert.deepEqual(
      obj.map((x) => x + 1),
      [11, 21],
      "map works"
    );
  });

  test("pluginApi.modifyClass works", function (assert) {
    class BaseArrayLike extends ArrayLikeObject {
      baseField = "base";

      get baseValue() {
        return this.baseField + this.length;
      }
    }
    class MidArrayLike extends BaseArrayLike {
      midField = "mid";

      get midValue() {
        return this.midField + (this[0] || 0);
      }
    }
    class FinalArrayLike extends MidArrayLike {
      finalField = "final";

      get finalValue() {
        return this.finalField + (this[1] || 0);
      }

      customMethod() {
        return this.baseValue + this.midValue + this.finalValue;
      }
    }

    getOwner(this).register(
      "final-array-like:main",
      new FinalArrayLike([10, 20, 30]),
      {
        instantiate: false,
      }
    );

    // Plugin API modifies the class
    withPluginApi((api) => {
      api.modifyClass("final-array-like:main", {
        pluginId: "array-like-object-test",
        extraField: "plugin!",
        _pluginValue: "initial",
        get pluginValue() {
          return (this.extraField || "") + (this[2] || 0) + this._pluginValue;
        },
        set pluginValue(val) {
          this._pluginValue = val;
        },
        _customSetterValue: 0,
        get customSetterValue() {
          return this._customSetterValue;
        },
        set customSetterValue(val) {
          this._customSetterValue = val * 2;
        },
        customMethod() {
          return "plugin-" + this.baseValue + this.midValue + this.finalValue;
        },
      });
    });

    const obj = getOwner(this).lookup("final-array-like:main");

    // Original inheritance chain still works
    assert.strictEqual(obj.baseField, "base", "base field present");
    assert.strictEqual(obj.baseValue, "base3", "base getter works");
    assert.strictEqual(obj.midField, "mid", "mid field present");
    assert.strictEqual(obj.midValue, "mid10", "mid getter works");
    assert.strictEqual(obj.finalField, "final", "final field present");
    assert.strictEqual(obj.finalValue, "final20", "final getter works");

    // Plugin modifications
    assert.strictEqual(obj.extraField, "plugin!", "plugin field present");
    assert.strictEqual(
      obj.pluginValue,
      "plugin!30initial",
      "plugin getter works"
    );
    obj.pluginValue = "changed";
    assert.strictEqual(
      obj.pluginValue,
      "plugin!30changed",
      "plugin setter works"
    );
    assert.strictEqual(
      obj._pluginValue,
      "changed",
      "plugin setter sets backing field"
    );

    assert.strictEqual(
      obj.customSetterValue,
      0,
      "customSetterValue getter works"
    );
    obj.customSetterValue = 5;
    assert.strictEqual(
      obj.customSetterValue,
      10,
      "customSetterValue setter works"
    );
    assert.strictEqual(
      obj._customSetterValue,
      10,
      "customSetterValue setter sets backing field"
    );

    assert.strictEqual(
      obj.customMethod(),
      "plugin-base3mid10final20",
      "plugin method overrides original"
    );

    // Array-like behavior
    assert.strictEqual(obj.length, 3, "length is correct");
    assert.strictEqual(obj[0], 10, "index access works");
    obj.push(40);
    assert.deepEqual([...obj], [10, 20, 30, 40], "push works");
    assert.strictEqual(obj.pop(), 40, "pop works");
    assert.deepEqual(
      obj.map((x) => x + 1),
      [11, 21, 31],
      "map works"
    );
  });
});
