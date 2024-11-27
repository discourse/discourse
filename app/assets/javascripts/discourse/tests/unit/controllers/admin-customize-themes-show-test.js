import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Theme from "admin/models/theme";

module("Unit | Controller | admin-customize-themes-show", function (hooks) {
  setupTest(hooks);

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

    const controller = this.owner.lookup(
      "controller:admin-customize-themes-show"
    );
    controller.setProperties({ model: remoteTheme });

    assert.deepEqual(
      controller.remoteThemeLink,
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

    const controller = this.owner.lookup(
      "controller:admin-customize-themes-show"
    );
    controller.setProperties({ model: remoteTheme });

    assert.deepEqual(
      controller.remoteThemeLink,
      "https://github.com/discourse/discourse-brand-header/tree/beta",
      "returns theme's repo URL to branch"
    );
  });

  test("displays settings editor button with settings", function (assert) {
    const theme = Theme.create({
      id: 2,
      default: true,
      name: "default",
      settings: [{}],
    });
    const controller = this.owner.lookup(
      "controller:admin-customize-themes-show"
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
      "controller:admin-customize-themes-show"
    );
    controller.setProperties({ model: theme });
    assert.false(
      controller.hasSettings,
      "sets the hasSettings property to true with settings"
    );
  });
});
