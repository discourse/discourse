import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Theme from "admin/models/theme";

module(
  "Unit | Controller | admin-customize-themes-show-index",
  function (hooks) {
    setupTest(hooks);

    test("displays settings editor button with settings", function (assert) {
      const theme = Theme.create({
        id: 2,
        default: true,
        name: "default",
        settings: [{}],
      });
      const controller = this.owner.lookup(
        "controller:admin-customize-themes-show-index"
      );
      controller.setProperties({ model: theme });
      assert.true(
        controller.hasSettings,
        "sets the hasSettings property to true with settings"
      );
    });

    test("hides settings editor button with no settings", function (assert) {
      const theme = Theme.create({
        id: 2,
        default: true,
        name: "default",
        settings: [],
      });
      const controller = this.owner.lookup(
        "controller:admin-customize-themes-show-index"
      );
      controller.setProperties({ model: theme });
      assert.false(
        controller.hasSettings,
        "sets the hasSettings property to true with settings"
      );
    });
  }
);
