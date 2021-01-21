import Theme from "admin/models/theme";
import { moduleFor } from "ember-qunit";
import { registerRouter } from "discourse/mapping-router";
import { test } from "qunit";

moduleFor("controller:admin-customize-themes-show", {
  beforeEach() {
    registerRouter(this.registry);
  },
  needs: ["controller:adminUser"],
});

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
  const controller = this.subject({
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
  const controller = this.subject({
    model: remoteTheme,
  });

  assert.deepEqual(
    controller.get("remoteThemeLink"),
    "https://github.com/discourse/discourse-brand-header/tree/beta",
    "returns theme's repo URL to branch"
  );
});
