import { getOwner } from "@ember/owner";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import { withPluginApi } from "discourse/lib/plugin-api";

module("Unit | lib | LegacyArrayLikeObject", function (hooks) {
  setupTest(hooks);

  test("constructs with default values", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const obj = LegacyArrayLikeObject.create();
        assert.true(
          obj instanceof LegacyArrayLikeObject,
          "returns an LegacyArrayLikeObject instance"
        );
        assert.strictEqual(obj.length, 0, "empty by default");
      }
    );
  });

  test("accepts initial items", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const obj = LegacyArrayLikeObject.create({ content: [1, 2, 3] });
        assert.deepEqual([...obj], [1, 2, 3], "contains initial items");
        assert.strictEqual(obj.length, 3, "length is correct");
      }
    );
  });

  test("accepts TrackedArray as items", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const arr = new TrackedArray([4, 5]);
        const obj = LegacyArrayLikeObject.create({ content: arr });
        assert.strictEqual(obj[0], 4);
        assert.strictEqual(obj[1], 5);
        assert.strictEqual(obj.length, 2);
      }
    );
  });

  test("assigns custom properties", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const obj = LegacyArrayLikeObject.create({ content: [1], foo: "bar" });
        assert.strictEqual(obj.foo, "bar", "property is assigned");
        obj.foo = "baz";
        assert.strictEqual(obj.foo, "baz", "property is settable");
      }
    );
  });

  test("throws if content is not an array", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        assert.throws(
          () => LegacyArrayLikeObject.create({ content: "not an array" }),
          /must be an array/
        );
      }
    );
  });

  test("array methods work", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        let obj = LegacyArrayLikeObject.create({ content: [1, 2] });
        obj.push(3);
        assert.deepEqual([...obj], [1, 2, 3]);
        assert.strictEqual(obj.pop(), 3);
        assert.deepEqual([...obj], [1, 2]);
        obj = LegacyArrayLikeObject.create({ content: [1, 2, 3, 4] });
        assert.deepEqual(
          obj.map((x) => x * 2),
          [2, 4, 6, 8],
          "map works"
        );
        assert.deepEqual(
          obj.filter((x) => x % 2 === 0),
          [2, 4],
          "filter works"
        );
        assert.strictEqual(
          obj.find((x) => x > 2),
          3,
          "find works"
        );
        assert.strictEqual(
          obj.findIndex((x) => x === 3),
          2,
          "findIndex works"
        );
        assert.true(
          obj.some((x) => x === 2),
          "some works"
        );
        assert.true(
          obj.every((x) => x > 0),
          "every works"
        );
        assert.false(
          obj.every((x) => x > 2),
          "every works for false"
        );
        assert.strictEqual(
          obj.reduce((a, b) => a + b, 0),
          10,
          "reduce works"
        );
        assert.deepEqual(obj.slice(1, 3), [2, 3], "slice works");
        assert.deepEqual(
          obj.concat([5, 6]),
          [1, 2, 3, 4, 5, 6],
          "concat works"
        );
        assert.deepEqual(obj.slice().reverse(), [4, 3, 2, 1], "reverse works");
        assert.true(obj.includes(3), "includes works");
        assert.false(obj.includes(99), "includes works for false");
        assert.strictEqual(obj.at(0), 1, "at(0) works");
        assert.strictEqual(obj.at(-1), 4, "at(-1) works");
      }
    );
  });

  test("instance properties take precedence over array", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        class CustomArrayLike extends LegacyArrayLikeObject {
          get first() {
            return "custom";
          }
        }
        const obj = CustomArrayLike.create({ content: [1, 2] });
        assert.strictEqual(obj.first, "custom");
      }
    );
  });

  test("subclassing works", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        class CustomArrayLike extends LegacyArrayLikeObject {
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
        const obj = CustomArrayLike.create({ content: [5, 6, 7] });
        assert.strictEqual(obj.customField, "foo", "custom field is present");
        assert.strictEqual(obj.bar, 42, "getter works");
        obj.bar = 100;
        assert.strictEqual(obj.bar, 100, "setter works");
        assert.strictEqual(obj.customMethod(), 30, "custom method works");
        assert.strictEqual(
          obj.firstPlusBar,
          105,
          "getter using array and field works"
        );
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
      }
    );
  });

  test("multiple levels of inheritance work as expected", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        class BaseArrayLike extends LegacyArrayLikeObject {
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

        const obj = FinalArrayLike.create({ content: [10, 20] });
        assert.strictEqual(obj.baseField, "base", "base field present");
        assert.strictEqual(obj.baseValue, "base2", "base getter works");
        assert.strictEqual(obj.midField, "mid", "mid field present");
        assert.strictEqual(obj.midValue, "mid10", "mid getter works");
        assert.strictEqual(obj.finalField, "final", "final field present");
        assert.strictEqual(obj.finalValue, "final20", "final getter works");
        assert.strictEqual(
          obj.customMethod(),
          "base2mid10final20",
          "custom method combines all levels"
        );
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
      }
    );
  });

  test("pluginApi.modifyClass works", function (assert) {
    class BaseArrayLike extends LegacyArrayLikeObject {
      baseField = "base";

      get baseValue() {
        return this.baseField + this.content.length;
      }
    }
    class MidArrayLike extends BaseArrayLike {
      midField = "mid";

      get midValue() {
        return this.midField + (this.content[0] || 0);
      }
    }
    class FinalArrayLike extends MidArrayLike {
      finalField = "final";
      _value = "initial";

      get valueGetter() {
        return "original";
      }

      get finalValue() {
        return this.finalField + (this.content[1] || 0);
      }

      customMethod() {
        return this.baseValue + this.midValue + this.finalValue;
      }
    }

    getOwner(this).register("final-array-like:main", FinalArrayLike);

    // Plugin API modifies the class
    withPluginApi((api) => {
      api.modifyClass(
        "final-array-like:main",
        (Superclass) =>
          class extends Superclass {
            // overriding getter from a base class works
            get valueGetter() {
              return super.valueGetter + " was modified";
            }

            get pluginValue() {
              return (this.content[2] || 0) + this._value;
            }

            set pluginValue(val) {
              this._value = val;
            }

            get customSetterValue() {
              return this._customSetterValue;
            }

            set customSetterValue(val) {
              this._customSetterValue = val * 2;
            }

            customMethod() {
              return (
                "plugin-" + this.baseValue + this.midValue + this.finalValue
              );
            }
          }
      );
    });

    const obj = getOwner(this).lookup("final-array-like:main");
    obj.content.push(10, 20, 30);

    // The original inheritance chain still works
    assert.strictEqual(obj.baseField, "base", "base field present");
    assert.strictEqual(obj.baseValue, "base3", "base getter works");
    assert.strictEqual(obj.midField, "mid", "mid field present");
    assert.strictEqual(obj.midValue, "mid10", "mid getter works");
    assert.strictEqual(obj.finalField, "final", "final field present");
    assert.strictEqual(obj.finalValue, "final20", "final getter works");

    // Plugin modifications
    assert.strictEqual(obj.pluginValue, "30initial", "plugin getter works");
    obj.pluginValue = "changed";
    assert.strictEqual(obj.pluginValue, "30changed", "plugin setter works");
    assert.strictEqual(
      obj._value,
      "changed",
      "plugin setter sets backing field"
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
      obj.customSetterValue,
      10,
      "customSetterValue getter works"
    );

    assert.strictEqual(
      obj.valueGetter,
      "original was modified",
      "plugin getter overrides original"
    );

    assert.strictEqual(
      obj.customMethod(),
      "plugin-base3mid10final20",
      "plugin method overrides original"
    );

    // Array-like behavior
    assert.strictEqual(obj.content.length, 3, "length is correct");
    assert.strictEqual(obj.content[0], 10, "index access works");
    obj.content.push(40);
    assert.deepEqual([...obj.content], [10, 20, 30, 40], "push works");
    assert.strictEqual(obj.content.pop(), 40, "pop works");
    assert.deepEqual(
      obj.content.map((x) => x + 1),
      [11, 21, 31],
      "map works"
    );
  });

  test("Array.isArray checks", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const obj = LegacyArrayLikeObject.create([1, 2, 3]);
        assert.true(
          Array.isArray(obj),
          "LegacyArrayLikeObject is considered an array"
        );
        assert.true(Array.isArray([...obj]), "spread result is a true array");
      }
    );
  });

  test("spread, for..of, for..in iteration", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const obj = LegacyArrayLikeObject.create([10, 20, 30]);
        assert.deepEqual([...obj], [10, 20, 30], "array spread works");
        const values = [];
        for (const v of obj) {
          values.push(v);
        }
        assert.deepEqual(values, [10, 20, 30], "for..of works");
        const keys = [];
        for (const k in obj) {
          if (!isNaN(Number(k))) {
            keys.push(Number(k));
          }
        }
        assert.deepEqual(keys, [0, 1, 2], "for..in yields array indices");
        obj.foo = "bar";
        const props = [];
        for (const k in obj) {
          if (obj.hasOwnProperty(k)) {
            props.push(k);
          }
        }
        assert.true(props.includes("foo"), "for..in yields custom properties");
        class SubArrayLike extends LegacyArrayLikeObject {
          custom = true;
        }
        const sub = SubArrayLike.create({ content: [1, 2] });
        const subKeys = [];
        for (const k in sub) {
          if (!sub.hasOwnProperty(k)) {
            continue;
          }
          subKeys.push(k);
        }
        assert.true(
          subKeys.includes("custom"),
          "for..in yields subclass properties"
        );
        const empty = LegacyArrayLikeObject.create();
        assert.deepEqual([...empty], [], "spread works for empty");
        const emptyVals = [];
        for (const v of empty) {
          emptyVals.push(v);
        }
        assert.deepEqual(emptyVals, [], "for..of works for empty");
      }
    );
  });

  test("object spread operator", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const obj = LegacyArrayLikeObject.create([1, 2, 3]);
        let spread = { ...obj };
        assert.deepEqual(
          Object.keys(spread),
          ["0", "1", "2"],
          "array indices are enumerable own properties by default"
        );
        assert.deepEqual(
          spread,
          { 0: 1, 1: 2, 2: 3 },
          "spread result contains array elements by default"
        );
        obj.foo = "bar";
        spread = { ...obj };
        assert.true(spread.hasOwnProperty("foo"), "custom property is present");
        assert.strictEqual(
          spread.foo,
          "bar",
          "custom property value is correct"
        );
        assert.strictEqual(spread[0], 1, "array element still present");
        obj[0] = 99;
        spread = { ...obj };
        assert.true(
          spread.hasOwnProperty("0"),
          "numeric property is present if own"
        );
        assert.strictEqual(
          spread[0],
          99,
          "numeric property value overrides array element"
        );
        class SubArrayLike extends LegacyArrayLikeObject {
          custom = 42;
        }
        const sub = SubArrayLike.create({ content: [5, 6] });
        let subSpread = { ...sub };
        assert.true(
          subSpread.hasOwnProperty("custom"),
          "subclass own property is present"
        );
        assert.strictEqual(
          subSpread.custom,
          42,
          "subclass property value is correct"
        );
        assert.strictEqual(subSpread[0], 5, "subclass array element present");
        const empty = LegacyArrayLikeObject.create();
        const emptySpread = { ...empty };
        assert.deepEqual(emptySpread, {}, "spread of empty object is empty");
      }
    );
  });

  test("content property returns underlying array", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const arr = [1, 2, 3];
        const obj = LegacyArrayLikeObject.create(arr);
        assert.deepEqual(
          obj.content,
          arr,
          "content property matches input array"
        );
        obj.push(4);
        assert.deepEqual(
          obj.content,
          [1, 2, 3, 4],
          "content property updates after mutation"
        );
      }
    );
  });

  test("constructor is private and cannot be called directly", function (assert) {
    assert.throws(() => {
      // eslint-disable-next-line no-new
      new LegacyArrayLikeObject([1, 2, 3]);
    }, /private constructor|is not a constructor|TypeError/);
  });
});
