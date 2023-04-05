import { module, skip, test } from "qunit";
import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupTest } from "ember-qunit";
import { getOwner } from "discourse-common/lib/get-owner";
import Sinon from "sinon";

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
      firstField = "firstFieldValue";
      otherField = "otherFieldValue";

      @discourseComputed
      prop() {
        return "howdy";
      }
    }

    getOwner(this).register("native-test-thingy:main", NativeTestThingy);

    withPluginApi("1.1.0", (api) => {
      api.modifyClass("native-test-thingy:main", {
        pluginId: "plugin-api-test",

        otherField: "new otherFieldValue",

        @discourseComputed
        prop() {
          return `${this._super(...arguments)} partner`;
        },
      });
    });

    const thingy = getOwner(this).lookup("native-test-thingy:main");
    assert.strictEqual(thingy.prop, "howdy partner");
    assert.strictEqual(thingy.firstField, "firstFieldValue");
    assert.strictEqual(thingy.otherField, "new otherFieldValue");
  });

  test("modifyClass works with native classes", function (assert) {
    class ClassTestThingy {
      firstField = "firstFieldValue";
      otherField = "otherFieldValue";

      get keep() {
        return "hey!";
      }

      get prop() {
        return "top of the morning";
      }
    }

    getOwner(this).register("class-test-thingy:main", ClassTestThingy, {
      instantiate: false,
    });

    const warnStub = Sinon.stub(console, "warn");

    withPluginApi("1.1.0", (api) => {
      api.modifyClass("class-test-thingy:main", {
        pluginId: "plugin-api-test",

        otherField: "new otherFieldValue",
        get prop() {
          return "g'day";
        },
      });
    });

    assert.strictEqual(
      warnStub.callCount,
      1,
      "fields warning was printed to console"
    );
    assert.true(warnStub.args[0][1].startsWith("Attempted to modify fields"));

    const thingy = new ClassTestThingy();

    assert.strictEqual(thingy.keep, "hey!", "maintains unchanged base getter");
    assert.strictEqual(thingy.prop, "g'day", "can override getter");
    assert.strictEqual(
      thingy.firstField,
      "firstFieldValue",
      "maintains unchanged base field"
    );
    assert.strictEqual(
      thingy.otherField,
      "otherFieldValue",
      "cannot override field"
    );
  });

  skip("modifyClass works with getters", function (assert) {
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
        get foo() {
          return "modified getter";
        },
      });
    });

    const obj = Base.create();
    assert.true(true, "no error thrown while merging mixin with getter");

    assert.strictEqual(obj.foo, "modified getter", "returns correct result");
  });
});
