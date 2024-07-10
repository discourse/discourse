import { getOwner } from "@ember/application";
import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed from "discourse-common/utils/decorators";

module("Unit | Utility | plugin-api", function (hooks) {
  setupTest(hooks);

  test("modifyClass works with classic Ember objects", function (assert) {
    const TestThingy = EmberObject.extend({
      @discourseComputed
      prop() {
        return "hello";
      },
    });

    getOwner(this).register("test-thingy:main", TestThingy);

    withPluginApi("1.1.0", (api) => {
      api.modifyClass("test-thingy:main", {
        pluginId: "plugin-api-test",

        @discourseComputed
        prop() {
          return `${this._super(...arguments)} there`;
        },
      });
    });

    const thingy = getOwner(this).lookup("test-thingy:main");
    assert.strictEqual(thingy.prop, "hello there");
  });

  test("modifyClass works with native class Ember objects", function (assert) {
    class NativeTestThingy extends EmberObject {
      @discourseComputed
      prop() {
        return "howdy";
      }
    }

    getOwner(this).register("native-test-thingy:main", NativeTestThingy);

    withPluginApi("1.1.0", (api) => {
      api.modifyClass("native-test-thingy:main", {
        pluginId: "plugin-api-test",

        @discourseComputed
        prop() {
          return `${this._super(...arguments)} partner`;
        },
      });
    });

    const thingy = getOwner(this).lookup("native-test-thingy:main");
    assert.strictEqual(thingy.prop, "howdy partner");
  });

  test("modifyClass works with native classes", function (assert) {
    class ClassTestThingy {
      get keep() {
        return "hey!";
      }

      get prop() {
        return "top of the morning";
      }
    }

    getOwner(this).register("class-test-thingy:main", new ClassTestThingy(), {
      instantiate: false,
    });

    withPluginApi("1.1.0", (api) => {
      api.modifyClass("class-test-thingy:main", {
        pluginId: "plugin-api-test",

        get prop() {
          return "g'day";
        },
      });
    });

    const thingy = getOwner(this).lookup("class-test-thingy:main");
    assert.strictEqual(thingy.keep, "hey!");
    assert.strictEqual(thingy.prop, "g'day");
  });

  test("modifyClass works with getters", function (assert) {
    let Base = EmberObject.extend({
      get foo() {
        throw new Error("base getter called");
      },
    });

    getOwner(this).register("test-class:main", Base, {
      instantiate: false,
    });

    // Performing this lookup triggers `factory._onLookup`. In DEBUG builds, that invokes injectedPropertyAssertion()
    // https://github.com/emberjs/ember.js/blob/36505f1b42/packages/%40ember/-internals/runtime/lib/system/core_object.js#L1144-L1163
    // Which in turn invokes `factory.proto()`.
    // This puts things in a state which will trigger https://github.com/emberjs/ember.js/issues/18860 when a native getter is overridden.
    withPluginApi("1.1.0", (api) => {
      api.modifyClass("test-class:main", {
        pluginId: "plugin-api-test",

        get foo() {
          return "modified getter";
        },
      });
    });

    const obj = Base.create();
    assert.true(true, "no error thrown while merging mixin with getter");

    assert.strictEqual(obj.foo, "modified getter", "returns correct result");
  });

  test("modifyClass works with modern callback syntax", function (assert) {
    class TestThingy {
      static someStaticMethod() {
        return "original static method";
      }
      someFunction() {
        return "original function";
      }
      get someGetter() {
        return "original getter";
      }
    }

    getOwner(this).register("test-thingy:main", TestThingy);

    withPluginApi("1.1.0", (api) => {
      api.modifyClass(
        "test-thingy:main",
        (Superclass) =>
          class extends Superclass {
            static someStaticMethod() {
              return `${super.someStaticMethod()} modified`;
            }

            someFunction() {
              return `${super.someFunction()} modified`;
            }

            get someGetter() {
              return `${super.someGetter} modified`;
            }
          }
      );

      const thingyKlass =
        getOwner(this).resolveRegistration("test-thingy:main");
      const thingy = new thingyKlass();
      assert.strictEqual(thingy.someFunction(), "original function modified");
      assert.strictEqual(thingy.someGetter, "original getter modified");
      assert.strictEqual(
        TestThingy.someStaticMethod(),
        "original static method modified"
      );
    });
  });
});
