import { mapRoutes } from "discourse/mapping-router";
import Theme from "admin/models/theme";

moduleFor("controller:admin-customize-themes-show", {
  beforeEach() {
    this.registry.register("router:main", mapRoutes());
  },
  needs: ["controller:adminUser"]
});

const repoUrl = "https://github.com/discourse/discourse-brand-header.git";
const remoteTheme = Theme.create({
  id: 2,
  default: true,
  name: "default",
  remote_theme: {
    remote_url: repoUrl
  }
});

QUnit.test("can display source url for remote themes", function(assert) {
  delete remoteTheme["remote_theme"]["branch"];
  const controller = this.subject({
    model: remoteTheme
  });

  assert.deepEqual(
    controller.get("remoteThemeLink"),
    repoUrl,
    "returns theme's repo URL"
  );
});

QUnit.test("can display source url for remote theme branches", function(
  assert
) {
  const branchUrl =
    "https://github.com/discourse/discourse-brand-header/tree/beta";
  remoteTheme["remote_theme"]["branch"] = "beta";

  const controller = this.subject({
    model: remoteTheme
  });

  assert.deepEqual(
    controller.get("remoteThemeLink"),
    branchUrl,
    "returns theme's repo URL to branch"
  );
});
