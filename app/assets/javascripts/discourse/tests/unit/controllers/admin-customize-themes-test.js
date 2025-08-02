import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Theme from "admin/models/theme";

module("Unit | Controller | admin-customize-themes", function (hooks) {
  setupTest(hooks);

  test("can list themes correctly", function (assert) {
    const defaultTheme = Theme.create({
      id: 2,
      default: true,
      name: "default",
    });
    const userTheme = Theme.create({
      id: 3,
      user_selectable: true,
      name: "name",
    });
    const strayTheme1 = Theme.create({ id: 4, name: "stray1" });
    const strayTheme2 = Theme.create({ id: 5, name: "stray2" });
    const componentTheme = Theme.create({
      id: 6,
      name: "component",
      component: true,
    });

    const controller = this.owner.lookup("controller:admin-customize-themes");
    controller.setProperties({
      model: [
        strayTheme2,
        strayTheme1,
        userTheme,
        defaultTheme,
        componentTheme,
      ],
    });

    assert.deepEqual(
      controller.fullThemes.map((t) => t.name),
      [strayTheme2, strayTheme1, userTheme, defaultTheme].map((t) => t.name),
      "returns a list of themes without components"
    );

    assert.deepEqual(
      controller.childThemes.map((t) => t.name),
      [componentTheme].map((t) => t.name),
      "separate components from themes"
    );
  });
});
