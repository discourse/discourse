import { module, test } from "qunit";
import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupTest } from "ember-qunit";
import { getOwner } from "discourse-common/lib/get-owner";

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
});
