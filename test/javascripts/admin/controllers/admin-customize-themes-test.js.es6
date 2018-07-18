import { mapRoutes } from "discourse/mapping-router";
import Theme from "admin/models/theme";

moduleFor("controller:admin-customize-themes", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:adminUser"]
});

QUnit.test("can list sorted themes", function(assert) {
  const defaultTheme = Theme.create({ id: 2, default: true, name: "default" });
  const userTheme = Theme.create({
    id: 3,
    user_selectable: true,
    name: "name"
  });
  const strayTheme1 = Theme.create({ id: 4, name: "stray1" });
  const strayTheme2 = Theme.create({ id: 5, name: "stray2" });

  const controller = this.subject({
    model: {
      content: [strayTheme2, strayTheme1, userTheme, defaultTheme]
    }
  });

  assert.deepEqual(
    controller.get("sortedThemes").map(t => t.get("name")),
    [defaultTheme, userTheme, strayTheme1, strayTheme2].map(t => t.get("name")),
    "sorts themes correctly"
  );
});
