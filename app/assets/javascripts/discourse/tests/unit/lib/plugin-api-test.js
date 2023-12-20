import { getOwner } from "@ember/application";
import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import allowClassModifications from "discourse/lib/allow-class-modifications";
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

  test("modifyClass works with two native classes", function (assert) {
    @allowClassModifications
    class ClassTestThingy {
      get keep() {
        return "hey!";
      }

      get prop() {
        return "top of the morning";
      }
    }

    withPluginApi("1.1.0", (api) => {
      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            get prop() {
              return "g'day";
            }
          }
      );
    });

    const thingy = new ClassTestThingy();
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

  test("modifyClassStatic works with classic Ember objects", function (assert) {
    const TestThingy = EmberObject.extend({});
    TestThingy.reopenClass({
      notCreate() {
        return "base";
      },
    });

    getOwner(this).register("test-thingy:main", TestThingy);

    withPluginApi("1.1.0", (api) => {
      api.modifyClassStatic("test-thingy:main", {
        pluginId: "plugin-api-test",

        notCreate() {
          return this._super() + "ball";
        },
      });
    });

    assert.strictEqual(TestThingy.notCreate(), "baseball");
  });

  // TODO: test modifying the same class twice

  // TODO: test modifying a constructor?

  // TODO: test combining modifyClass and modifyClassStatic

  test("modifyClassStatic works with two native classes", function (assert) {
    // class Base {
    //   static boop() {
    //     return 1;
    //   }
    // }

    // class X {
    //   static boop() {
    //     return super.boop() + 1;
    //   }
    // }

    // // Object.setPrototypeOf(X, Base);

    // // const protoParent = class {};
    // const protoChain = class {};
    // Object.setPrototypeOf(protoChain, Base);
    // X.boop = X.boop.bind(protoChain);

    // debugger;
    // const z = X.boop();

    @allowClassModifications
    class ClassTestThingy {
      static notCreate() {
        debugger;
        return "base";
      }
    }

    // class X extends ClassTestThingy {
    //   static notCreate() {
    //     return super.notCreate() + "ment";
    //   }
    // }

    // debugger;
    // const z = X.notCreate();

    withPluginApi("1.1.0", (api) => {
      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            static notCreate() {
              debugger;
              return super.notCreate() + "ball";
              // return "ball";
            }
          }
      );
    });

    assert.strictEqual(ClassTestThingy.notCreate(), "baseball");
  });
});
