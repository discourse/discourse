import Component from "@glimmer/component";
import EmberObject, { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { block } from "discourse/blocks";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";
import { _INTERNAL_SOURCE_KEY, apiInitializer } from "discourse/lib/api";
import { rollbackAllPrepends } from "discourse/lib/class-prepend";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  getBlockEntry,
  hasBlock,
  hasConditionType,
  isValidOutlet,
  resetBlockRegistryForTesting,
} from "discourse/tests/helpers/block-testing";
import DeprecationCounter from "discourse/tests/helpers/deprecation-counter";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";

module("Unit | Utility | plugin-api", function (hooks) {
  setupTest(hooks);

  test("modifyClass works with classic Ember objects", function (assert) {
    // eslint-disable-next-line ember/no-classic-classes
    const TestThingy = EmberObject.extend({
      prop: computed(function () {
        return "hello";
      }),
    });

    getOwner(this).register("test-thingy:main", TestThingy);

    withPluginApi((api) => {
      api.modifyClass("test-thingy:main", {
        pluginId: "plugin-api-test",

        prop: computed(function () {
          return `${this._super(...arguments)} there`;
        }),
      });
    });

    const thingy = getOwner(this).lookup("test-thingy:main");
    assert.strictEqual(thingy.prop, "hello there");
  });

  test("modifyClass works with native class Ember objects", function (assert) {
    class NativeTestThingy extends EmberObject {
      @computed
      get prop() {
        return "howdy";
      }
    }

    getOwner(this).register("native-test-thingy:main", NativeTestThingy);

    withPluginApi((api) => {
      api.modifyClass("native-test-thingy:main", {
        pluginId: "plugin-api-test",

        prop: computed(function () {
          return `${this._super(...arguments)} partner`;
        }),
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

    withPluginApi((api) => {
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
    let Base = class extends EmberObject {
      get foo() {
        throw new Error("base getter called");
      }
    };

    getOwner(this).register("test-class:main", Base, {
      instantiate: false,
    });

    // Performing this lookup triggers `factory._onLookup`. In DEBUG builds, that invokes injectedPropertyAssertion()
    // https://github.com/emberjs/ember.js/blob/36505f1b42/packages/%40ember/-internals/runtime/lib/system/core_object.js#L1144-L1163
    // Which in turn invokes `factory.proto()`.
    // This puts things in a state which will trigger https://github.com/emberjs/ember.js/issues/18860 when a native getter is overridden.
    withPluginApi((api) => {
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

    withPluginApi((api) => {
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

      api.modifyClass(
        "test-thingy:main",
        (Superclass) =>
          class extends Superclass {
            someFunction() {
              return `${super.someFunction()} twice`;
            }
          }
      );

      const thingyKlass =
        getOwner(this).resolveRegistration("test-thingy:main");
      const thingy = new thingyKlass();
      assert.strictEqual(
        thingy.someFunction(),
        "original function modified twice"
      );
      assert.strictEqual(thingy.someGetter, "original getter modified");
      assert.strictEqual(
        TestThingy.someStaticMethod(),
        "original static method modified"
      );
    });
  });

  test("modifyClass works with a combination of callback and legacy syntax", function (assert) {
    class TestThingy extends EmberObject {
      someMethod() {
        return "original";
      }
    }

    getOwner(this).register("test-thingy:main", TestThingy);

    const fakeInit = () => {
      withPluginApi((api) => {
        api.modifyClass("test-thingy:main", {
          someMethod() {
            return `${this._super()} reopened`;
          },
          pluginId: "one",
        });

        api.modifyClass(
          "test-thingy:main",
          (Superclass) =>
            class extends Superclass {
              someMethod() {
                return `${super.someMethod()}, prepended`;
              }
            }
        );

        api.modifyClass("test-thingy:main", {
          someMethod() {
            return `${this._super()}, reopened2`;
          },
          pluginId: "two",
        });
      });
    };

    fakeInit();

    assert.strictEqual(
      new TestThingy().someMethod(),
      "original reopened, reopened2, prepended",
      "it works after first application"
    );

    for (let i = 0; i < 3; i++) {
      rollbackAllPrepends();
      fakeInit();
    }

    assert.strictEqual(
      new TestThingy().someMethod(),
      "original reopened, reopened2, prepended",
      "it works when rolled back and re-applied multiple times"
    );
  });

  module("model deprecation", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      disableRaiseOnDeprecation();
      // the deprecations below are expected, keep them out of the test output
      // and out of the counter
      sinon.stub(console, "warn");
      this.counterStub = sinon.stub(
        DeprecationCounter.prototype,
        "incrementCount"
      );

      getOwner(this).register(
        "model:test-model",
        class extends EmberObject {
          static someStaticMethod() {
            return "original static";
          }

          someMethod() {
            return "original";
          }
        }
      );
    });

    nestedHooks.afterEach(function () {
      enableRaiseOnDeprecation();
    });

    test("modifyClass deprecates for model types", function (assert) {
      withPluginApi((api) => {
        api.modifyClass(
          "model:test-model",
          (Superclass) =>
            class extends Superclass {
              someMethod() {
                return `${super.someMethod()} modified`;
              }
            }
        );
      });

      assert.true(
        this.counterStub.calledWith("discourse.modify-class-model"),
        "triggers the deprecation"
      );

      assert.strictEqual(
        getOwner(this).lookup("model:test-model").someMethod(),
        "original modified",
        "still applies the modification"
      );
    });

    test("modifyClassStatic deprecates for model types", function (assert) {
      withPluginApi((api) => {
        api.modifyClassStatic("model:test-model", {
          pluginId: "plugin-api-test",

          someStaticMethod() {
            return "overridden static";
          },
        });
      });

      assert.true(
        this.counterStub.calledWith("discourse.modify-class-model"),
        "triggers the deprecation"
      );

      assert.strictEqual(
        getOwner(this)
          .resolveRegistration("model:test-model")
          .someStaticMethod(),
        "overridden static",
        "still applies the modification"
      );
    });

    test("does not deprecate for other types", function (assert) {
      getOwner(this).register(
        "test-thingy:main",
        class {
          someMethod() {
            return "original";
          }
        }
      );

      withPluginApi((api) => {
        api.modifyClass(
          "test-thingy:main",
          (Superclass) =>
            class extends Superclass {
              someMethod() {
                return `${super.someMethod()} modified`;
              }
            }
        );
      });

      assert.false(
        this.counterStub.calledWith("discourse.modify-class-model"),
        "does not trigger the deprecation"
      );
    });
  });

  module("Block APIs", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      resetBlockRegistryForTesting();
    });

    module("registerBlock", function () {
      test("registers a block class directly", function (assert) {
        @block("api-direct-block")
        class ApiDirectBlock extends Component {}

        withPluginApi((api) => {
          api.registerBlock(ApiDirectBlock);
        });

        assert.true(hasBlock("api-direct-block"));
        assert.strictEqual(getBlockEntry("api-direct-block"), ApiDirectBlock);
      });

      test("registers a block factory with string name", function (assert) {
        @block("api-factory-block")
        class ApiFactoryBlock extends Component {}

        withPluginApi((api) => {
          api.registerBlock("api-factory-block", async () => ApiFactoryBlock);
        });

        assert.true(hasBlock("api-factory-block"));
      });

      test("throws when factory is missing for string name", function (assert) {
        withPluginApi((api) => {
          assert.throws(
            () => api.registerBlock("missing-factory"),
            /requires a factory function/
          );
        });
      });

      test("throws when factory is not a function", function (assert) {
        withPluginApi((api) => {
          assert.throws(
            () => api.registerBlock("invalid-factory", "not a function"),
            /requires a factory function/
          );
        });
      });
    });

    module("registerBlockOutlet", function () {
      test("registers a custom outlet", function (assert) {
        withPluginApi((api) => {
          api.registerBlockOutlet("api-custom-outlet");
        });

        assert.true(isValidOutlet("api-custom-outlet"));
      });

      test("registers outlet with options", function (assert) {
        withPluginApi((api) => {
          api.registerBlockOutlet("api-described-outlet", {
            description: "A test outlet",
          });
        });

        assert.true(isValidOutlet("api-described-outlet"));
      });

      test("works without options parameter", function (assert) {
        withPluginApi((api) => {
          api.registerBlockOutlet("api-no-options-outlet");
        });

        assert.true(isValidOutlet("api-no-options-outlet"));
      });
    });

    module("registerBlockConditionType", function () {
      test("registers a custom condition type", function (assert) {
        @blockCondition({
          type: "api-test-condition",
          args: {
            enabled: { type: "boolean" },
          },
        })
        class ApiTestCondition extends BlockCondition {
          evaluate(args) {
            return args.enabled === true;
          }
        }

        withPluginApi((api) => {
          api.registerBlockConditionType(ApiTestCondition);
        });

        assert.true(hasConditionType("api-test-condition"));
      });
    });

    module("renderBlocks", function () {
      test("throws for unknown outlet", function (assert) {
        @block("render-test-block")
        class RenderTestBlock extends Component {}

        withPluginApi((api) => {
          api.registerBlock(RenderTestBlock);

          assert.throws(
            () =>
              api.renderBlocks("nonexistent-outlet", [
                { block: RenderTestBlock },
              ]),
            /Unknown block outlet/
          );
        });
      });
    });
  });

  module("Customization source", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      resetBlockRegistryForTesting();
    });

    // The build emits a frozen source, so these mirror it.
    function pluginOpts(name, opts) {
      const source = Object.freeze({ type: "plugin", name });
      return { ...opts, [_INTERNAL_SOURCE_KEY]: source };
    }

    function themeOpts(id, opts) {
      const source = Object.freeze({ type: "theme", id });
      return { ...opts, [_INTERNAL_SOURCE_KEY]: source };
    }

    test("binds the source from opts to the api", function (assert) {
      let boundSource, receivedOpts;

      withPluginApi(
        (api, opts) => {
          boundSource = api.source;
          receivedOpts = opts;
        },
        pluginOpts("chat", { foo: 1 })
      );

      assert.strictEqual(boundSource.type, "plugin");
      assert.strictEqual(boundSource.name, "chat");
      assert.strictEqual(receivedOpts.foo, 1, "user opts are preserved");
    });

    test("core code (no source) gets a core source", function (assert) {
      let api;
      withPluginApi((a) => (api = a));

      assert.deepEqual(api.source, { type: "core" });
      assert.strictEqual(
        typeof api.getCurrentUser,
        "function",
        "the api methods are available"
      );
    });

    test("every call gets its own api carrying its own source", function (assert) {
      let first, second, other;

      withPluginApi((api) => (first = api), pluginOpts("chat"));
      withPluginApi((api) => (second = api), pluginOpts("chat"));
      withPluginApi((api) => (other = api), themeOpts(1));

      assert.notStrictEqual(first, second, "instances are not shared");
      assert.deepEqual(first.source, second.source);
      assert.deepEqual(other.source, { type: "theme", id: 1 });
      assert.strictEqual(
        typeof first.getCurrentUser,
        "function",
        "each one exposes the full PluginApi surface"
      );
    });

    test("legacy version-string signature still binds the source", function (assert) {
      let boundSource;

      withPluginApi(
        // eslint-disable-next-line discourse/plugin-api-no-version -- intentionally exercising the legacy version-string signature
        "1.0",
        (api) => (boundSource = api.source),
        pluginOpts("chat")
      );

      assert.strictEqual(boundSource.type, "plugin");
      assert.strictEqual(boundSource.name, "chat");
    });

    test("apiInitializer forwards the source to the callback", function (assert) {
      let boundSource;

      const initializer = apiInitializer(
        (api) => (boundSource = api.source),
        pluginOpts("chat")
      );
      initializer.initialize();

      assert.strictEqual(boundSource.type, "plugin");
      assert.strictEqual(boundSource.name, "chat");
    });

    test("attribution comes from the source, not the call stack", function (assert) {
      // Code with no source is core and may use any namespace, whatever frames
      // are on the stack.
      @block("any-namespace-block")
      class CoreNamespacedBlock extends Component {}

      withPluginApi((api) => api.registerBlock(CoreNamespacedBlock));
      assert.true(
        hasBlock("any-namespace-block"),
        "core code may register any name"
      );

      // A plugin source enforces the plugin namespace.
      @block("unnamespaced-from-plugin")
      class PluginBlock extends Component {}

      withPluginApi((api) => {
        assert.throws(
          () => api.registerBlock(PluginBlock),
          /Plugin blocks must use the "namespace:block-name" format/
        );
      }, pluginOpts("chat"));

      // The same plugin can register a correctly namespaced block.
      @block("chat:source-block")
      class NamespacedPluginBlock extends Component {}

      withPluginApi(
        (api) => api.registerBlock(NamespacedPluginBlock),
        pluginOpts("chat")
      );
      assert.true(hasBlock("chat:source-block"));
    });

    test("the api can invoke methods that use private members", function (assert) {
      // modifyClass touches a #private, which brand-checks, so the api has to be
      // a real instance rather than something made with Object.create.
      class SourceThing {}
      getOwner(this).register("source-thing:main", SourceThing);

      withPluginApi((api) => {
        api.modifyClass(
          "source-thing:main",
          (Superclass) => class extends Superclass {}
        );
      }, pluginOpts("chat"));

      assert.true(true, "modifyClass works on a source-carrying api");
    });

    test("source cannot be reassigned or mutated", function (assert) {
      let api;
      withPluginApi((a) => (api = a), pluginOpts("chat"));

      assert.throws(
        () => (api.source = { type: "plugin", name: "evil" }),
        TypeError,
        "the source binding cannot be reassigned"
      );
      assert.throws(
        () => (api.source.name = "evil"),
        TypeError,
        "the source object is frozen by the build"
      );
      assert.strictEqual(
        api.source.name,
        "chat",
        "the source is unchanged after both attempts"
      );
    });
  });
});
