import Component from "@glimmer/component";
import EmberObject, { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";
import { apiInitializer } from "discourse/lib/api";
import { rollbackAllPrepends } from "discourse/lib/class-prepend";
import { SOURCE_BRAND } from "discourse/lib/customization-source";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  getBlockEntry,
  hasBlock,
  hasConditionType,
  isValidOutlet,
  resetBlockRegistryForTesting,
} from "discourse/tests/helpers/block-testing";

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

    function pluginSource(name) {
      return { [SOURCE_BRAND]: true, type: "plugin", name };
    }

    function themeSource(id) {
      return { [SOURCE_BRAND]: true, type: "theme", id };
    }

    test("binds the build-injected source to the api and strips it from opts", function (assert) {
      let boundSource, receivedOpts;

      withPluginApi(
        (api, opts) => {
          boundSource = api.source;
          receivedOpts = opts;
        },
        { foo: 1 },
        pluginSource("chat")
      );

      assert.strictEqual(boundSource.type, "plugin");
      assert.strictEqual(boundSource.name, "chat");
      assert.strictEqual(receivedOpts.foo, 1, "user opts are preserved");
      assert.false(
        SOURCE_BRAND in receivedOpts,
        "the source descriptor does not leak into opts"
      );
    });

    test("core code (no descriptor) gets the singleton with a core source", function (assert) {
      let api;
      withPluginApi((a) => (api = a));

      assert.deepEqual(api.source, { type: "core" });
      assert.strictEqual(
        typeof api.getCurrentUser,
        "function",
        "the singleton's methods are available"
      );
    });

    test("caches one bound api per source; each exposes the full api", function (assert) {
      let first, second, other, core;

      withPluginApi((api) => (first = api), {}, pluginSource("chat"));
      withPluginApi((api) => (second = api), {}, pluginSource("chat"));
      withPluginApi((api) => (other = api), {}, themeSource(1));
      withPluginApi((api) => (core = api));

      assert.strictEqual(first, second, "same source reuses one bound api");
      assert.notStrictEqual(first, other, "different sources are distinct");
      assert.notStrictEqual(
        first,
        core,
        "bound api differs from the singleton"
      );
      assert.strictEqual(
        typeof first.getCurrentUser,
        "function",
        "bound api exposes the full PluginApi surface"
      );
    });

    test("legacy version-string signature still binds the source", function (assert) {
      let boundSource;

      withPluginApi(
        // eslint-disable-next-line discourse/plugin-api-no-version -- intentionally exercising the legacy version-string signature
        "1.0",
        (api) => (boundSource = api.source),
        {},
        pluginSource("chat")
      );

      assert.strictEqual(boundSource.type, "plugin");
      assert.strictEqual(boundSource.name, "chat");
    });

    test("apiInitializer forwards the source to the callback", function (assert) {
      let boundSource;

      const initializer = apiInitializer(
        (api) => (boundSource = api.source),
        {},
        pluginSource("chat")
      );
      initializer.initialize();

      assert.strictEqual(boundSource.type, "plugin");
      assert.strictEqual(boundSource.name, "chat");
    });

    test("attribution comes from the descriptor, not the call stack", function (assert) {
      // The descriptor alone decides the source. Code with no descriptor is
      // treated as core (and may use any namespace) regardless of whatever
      // frames happen to be on the stack — this is the regression guard for the
      // monkey-patched-stack misattribution bug.
      @block("any-namespace-block")
      class CoreNamespacedBlock extends Component {}

      withPluginApi((api) => api.registerBlock(CoreNamespacedBlock));
      assert.true(
        hasBlock("any-namespace-block"),
        "core code may register any name"
      );

      // A plugin descriptor enforces the plugin namespace.
      @block("unnamespaced-from-plugin")
      class PluginBlock extends Component {}

      withPluginApi(
        (api) => {
          assert.throws(
            () => api.registerBlock(PluginBlock),
            /Plugin blocks must use the "namespace:block-name" format/
          );
        },
        {},
        pluginSource("chat")
      );

      // The same plugin can register a correctly namespaced block.
      @block("chat:source-block")
      class NamespacedPluginBlock extends Component {}

      withPluginApi(
        (api) => api.registerBlock(NamespacedPluginBlock),
        {},
        pluginSource("chat")
      );
      assert.true(hasBlock("chat:source-block"));
    });

    test("source-bound api can invoke methods that use private members", function (assert) {
      // The source-bound api must be a real PluginApi instance, not a prototype
      // proxy: methods like modifyClass touch a #private, which brand-checks
      // against real instances and throws "Receiver must be an instance of
      // class" on anything created via Object.create.
      class SourceThing {}
      getOwner(this).register("source-thing:main", SourceThing);

      withPluginApi(
        (api) => {
          api.modifyClass(
            "source-thing:main",
            (Superclass) => class extends Superclass {}
          );
        },
        {},
        pluginSource("chat")
      );

      assert.true(true, "modifyClass works on a source-bound api");
    });

    test("source is read-only and frozen", function (assert) {
      let api;
      withPluginApi((a) => (api = a), {}, pluginSource("chat"));

      assert.throws(
        () => (api.source = { type: "plugin", name: "evil" }),
        TypeError,
        "the source binding cannot be reassigned"
      );
      assert.throws(
        () => (api.source.name = "evil"),
        TypeError,
        "the source object cannot be mutated"
      );
      assert.strictEqual(
        api.source.name,
        "chat",
        "the source is unchanged after both attempts"
      );
    });
  });
});
