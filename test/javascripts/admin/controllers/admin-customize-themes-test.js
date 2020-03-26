import { mapRoutes } from "discourse/mapping-router";
import Theme from "admin/models/theme";

moduleFor("controller:admin-customize-themes", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:adminUser"]
});

QUnit.test("can list themes correctly", function(assert) {
  const defaultTheme = Theme.create({ id: 2, default: true, name: "default" });
  const userTheme = Theme.create({
    id: 3,
    user_selectable: true,
    name: "name"
  });
  const strayTheme1 = Theme.create({ id: 4, name: "stray1" });
  const strayTheme2 = Theme.create({ id: 5, name: "stray2" });
  const componentTheme = Theme.create({
    id: 6,
    name: "component",
    component: true
  });

  const controller = this.subject({
    model: [strayTheme2, strayTheme1, userTheme, defaultTheme, componentTheme]
  });

  assert.deepEqual(
    controller.get("fullThemes").map(t => t.get("name")),
    [strayTheme2, strayTheme1, userTheme, defaultTheme].map(t => t.get("name")),
    "returns a list of themes without components"
  );

  assert.deepEqual(
    controller.get("childThemes").map(t => t.get("name")),
    [componentTheme].map(t => t.get("name")),
    "separate components from themes"
  );
});
