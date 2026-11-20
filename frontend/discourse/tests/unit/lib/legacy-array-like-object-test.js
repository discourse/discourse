import { set } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedArray } from "@ember/reactive/collections";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import LegacyArrayLikeObject from "discourse/lib/legacy-array-like-object";
import { withPluginApi } from "discourse/lib/plugin-api";
import { isTrackedArray } from "discourse/lib/tracked-tools";

module("Unit | lib | LegacyArrayLikeObject", function (hooks) {
  setupTest(hooks);

  test("constructs with default values", function (assert) {
    const obj = LegacyArrayLikeObject.create();
    assert.true(obj instanceof LegacyArrayLikeObject);
    assert.deepEqual(obj.content, [], "content is empty by default");
  });

  test("wraps initial items in a TrackedArray", function (assert) {
    const obj = LegacyArrayLikeObject.create({ content: [1, 2, 3] });
    assert.deepEqual([...obj.content], [1, 2, 3]);
    assert.true(isTrackedArray(obj.content));
  });

  test("keeps a TrackedArray passed as content", function (assert) {
    const arr = trackedArray([4, 5]);
    const obj = LegacyArrayLikeObject.create({ content: arr });
    assert.strictEqual(obj.content, arr);
  });

  test("assigns custom properties", function (assert) {
    const obj = LegacyArrayLikeObject.create({ content: [1], foo: "bar" });
    assert.strictEqual(obj.foo, "bar", "property is assigned");
    obj.foo = "baz";
    assert.strictEqual(obj.foo, "baz", "property is settable");
  });

  test("throws if content is not an array", function (assert) {
    assert.throws(
      () => LegacyArrayLikeObject.create({ content: "not an array" }),
      /must be an array/
    );
  });

  test("content can be mutated but not replaced", function (assert) {
    const obj = LegacyArrayLikeObject.create({ content: [1, 2] });
    const content = obj.content;

    obj.content.push(3);
    assert.deepEqual([...obj.content], [1, 2, 3]);

    assert.throws(() => {
      obj.content = [];
    }, TypeError);
    assert.throws(() => set(obj, "content", []), TypeError);
    assert.strictEqual(obj.content, content, "content is the same array");
  });

  test("content is not an own enumerable property", function (assert) {
    const obj = LegacyArrayLikeObject.create({ content: [1], foo: "bar" });
    assert.false(Object.keys(obj).includes("content"));
    assert.false(Object.hasOwn({ ...obj }, "content"));
    assert.strictEqual({ ...obj }.foo, "bar");
  });

  test("does not behave like an array", function (assert) {
    const obj = LegacyArrayLikeObject.create({ content: [1, 2, 3] });
    assert.false(Array.isArray(obj));
    assert.strictEqual(obj.length, undefined);
    assert.strictEqual(obj[0], undefined);
    assert.strictEqual(obj.map, undefined);
    assert.false(Symbol.iterator in obj);
    assert.deepEqual(Object.keys({ ...obj }), []);
  });

  test("subclass members work alongside content", function (assert) {
    class BaseArrayLike extends LegacyArrayLikeObject {
      baseField = "base";

      get baseValue() {
        return this.baseField + this.content.length;
      }
    }

    class FinalArrayLike extends BaseArrayLike {
      finalField = "final";
      #bar = 42;

      get bar() {
        return this.#bar;
      }

      set bar(val) {
        this.#bar = val;
      }

      get finalValue() {
        return this.finalField + (this.content[0] || 0);
      }

      customMethod() {
        return this.baseValue + this.finalValue;
      }
    }

    const obj = FinalArrayLike.create({
      content: [10, 20],
      finalField: "set",
    });
    assert.true(obj instanceof BaseArrayLike);
    assert.strictEqual(obj.baseField, "base", "base field is present");
    assert.strictEqual(obj.finalField, "set", "create overrides field values");
    assert.strictEqual(obj.bar, 42, "getter works");
    obj.bar = 100;
    assert.strictEqual(obj.bar, 100, "setter works");
    assert.strictEqual(obj.customMethod(), "base2set10", "method works");
    obj.content.push(30);
    assert.strictEqual(obj.baseValue, "base3", "getter sees content changes");
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

            // overriding getter from a base class works
            get valueGetter() {
              return super.valueGetter + " was modified";
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

  test("constructor is private and cannot be called directly", function (assert) {
    assert.throws(() => {
      // eslint-disable-next-line no-new
      new LegacyArrayLikeObject([1, 2, 3]);
    }, /not constructable/);
  });
});
