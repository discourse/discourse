import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";

discourseModule("Unit | Utility | plugin-api", function () {
  test("modifyClass works with classic Ember objects", function (assert) {
    const TestThingy = EmberObject.extend({
      @discourseComputed
      prop() {
        return "hello";
      },
    });

    this.registry.register("test-thingy:main", TestThingy);

    withPluginApi("1.1.0", (api) => {
      api.modifyClass("test-thingy:main", {
        pluginId: "plugin-api-test",

        @discourseComputed
        prop() {
          return `${this._super(...arguments)} there`;
        },
      });
    });

    const thingy = this.container.lookup("test-thingy:main");
    assert.strictEqual(thingy.prop, "hello there");
  });

  test("modifyClass works with native class Ember objects", function (assert) {
    class NativeTestThingy extends EmberObject {
      @discourseComputed
      prop() {
        return "howdy";
      }
    }

    this.registry.register("native-test-thingy:main", NativeTestThingy);

    withPluginApi("1.1.0", (api) => {
      api.modifyClass("native-test-thingy:main", {
        pluginId: "plugin-api-test",

        @discourseComputed
        prop() {
          return `${this._super(...arguments)} partner`;
        },
      });
    });

    const thingy = this.container.lookup("native-test-thingy:main");
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

    this.registry.register("class-test-thingy:main", new ClassTestThingy(), {
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

    const thingy = this.container.lookup("class-test-thingy:main");
    assert.strictEqual(thingy.keep, "hey!");
    assert.strictEqual(thingy.prop, "g'day");
  });
});
