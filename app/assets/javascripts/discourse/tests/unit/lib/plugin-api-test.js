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

  test("modifyClass works native class constructors", function (assert) {
    @allowClassModifications
    class ClassTestThingy {
      constructor(value) {
        this.result = value;
      }
    }

    withPluginApi("1.1.0", (api) => {
      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            constructor(value) {
              super(value);
              this.result = this.result * 2;
            }
          }
      );

      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            constructor(value) {
              super(value);
              this.result += 1;
            }
          }
      );
    });

    assert.strictEqual(new ClassTestThingy(5).result, 11);
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

  test("modifyClass works with static methods and two native classes", function (assert) {
    @allowClassModifications
    class ClassTestThingy {
      static bar() {
        return "base";
      }
    }

    withPluginApi("1.1.0", (api) => {
      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            static bar() {
              return super.bar() + "ball";
            }
          }
      );
    });

    assert.strictEqual(ClassTestThingy.bar(), "baseball");
  });

  test("modifyClass works when modifying the same class twice", function (assert) {
    @allowClassModifications
    class ClassTestThingy {
      static bar() {
        return "base";
      }

      foo() {
        return 1;
      }
    }

    withPluginApi("1.1.0", (api) => {
      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            static bar() {
              return super.bar() + "ball";
            }

            foo() {
              return super.foo() + 2;
            }
          }
      );

      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            static bar() {
              return `${super.bar()} game`;
            }

            foo() {
              return super.foo() + 3;
            }
          }
      );
    });

    assert.strictEqual(ClassTestThingy.bar(), "baseball game");
    assert.strictEqual(new ClassTestThingy().foo(), 6);
  });

  test("modifyClass works with classes that use inheritance", function (assert) {
    class ActualBase {
      static bar() {
        return 2;
      }

      array = [];

      constructor() {
        this.array.push("base");
      }

      foo() {
        return 1;
      }
    }

    class SomeBase extends ActualBase {
      static bar() {
        return super.bar() * 2;
      }

      constructor() {
        super(...arguments);
        this.array.push("other");
      }

      foo() {
        return super.foo() + 1;
      }
    }

    @allowClassModifications
    class ClassTestThingy extends SomeBase {
      static bar() {
        return super.bar() * 2;
      }

      constructor() {
        super(...arguments);
        this.array.push("thingy");
      }

      foo() {
        return super.foo() + 1;
      }
    }

    withPluginApi("1.1.0", (api) => {
      api.modifyClass(
        ClassTestThingy,
        (Base) =>
          class extends Base {
            static bar() {
              return super.bar() * 2;
            }

            constructor() {
              super(...arguments);
              this.array.push("modification");
            }

            foo() {
              return super.foo() + 1;
            }
          }
      );
    });

    assert.strictEqual(ClassTestThingy.bar(), 16);
    assert.deepEqual(new ClassTestThingy().array, [
      "base",
      "other",
      "thingy",
      "modification",
    ]);
    assert.strictEqual(new ClassTestThingy().foo(), 4);
  });
});
