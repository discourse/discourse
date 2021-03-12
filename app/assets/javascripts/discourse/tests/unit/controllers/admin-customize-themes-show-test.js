import Theme from "admin/models/theme";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";

discourseModule("Unit | Controller | admin-customize-themes-show", function () {
  test("can display source url for remote themes", function (assert) {
    const repoUrl = "https://github.com/discourse/discourse-brand-header.git";
    const remoteTheme = Theme.create({
      id: 2,
      default: true,
      name: "default",
      remote_theme: {
        remote_url: repoUrl,
      },
    });
    const controller = this.getController("admin-customize-themes-show", {
      model: remoteTheme,
    });

    assert.deepEqual(
      controller.get("remoteThemeLink"),
      repoUrl,
      "returns theme's repo URL"
    );
  });

  test("can display source url for remote theme branches", function (assert) {
    const remoteTheme = Theme.create({
      id: 2,
      default: true,
      name: "default",
      remote_theme: {
        remote_url: "https://github.com/discourse/discourse-brand-header.git",
        branch: "beta",
      },
    });
    const controller = this.getController("admin-customize-themes-show", {
      model: remoteTheme,
    });

    assert.deepEqual(
      controller.get("remoteThemeLink"),
      "https://github.com/discourse/discourse-brand-header/tree/beta",
      "returns theme's repo URL to branch"
    );
  });
});
