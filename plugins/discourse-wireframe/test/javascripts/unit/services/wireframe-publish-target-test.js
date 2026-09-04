import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module(
  "Unit | Discourse Wireframe | service:wireframe-publish-target",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.theme = getOwner(this).lookup("service:wireframe-publish-target");
    });

    test("setActiveTheme binds the active theme", function (assert) {
      this.theme.setActiveTheme(7);
      assert.strictEqual(this.theme.activeThemeId, 7);
    });

    test("reset clears the active theme", function (assert) {
      this.theme.setActiveTheme(7);
      this.theme.reset();
      assert.strictEqual(this.theme.activeThemeId, null);
    });

    test("activeThemeIsSystem detects core (negative-id) themes", function (assert) {
      this.theme.setActiveTheme(-1);
      assert.true(this.theme.activeThemeIsSystem);
      this.theme.setActiveTheme(7);
      assert.false(this.theme.activeThemeIsSystem);
    });

    test("activeThemeIsSystem is false with no active theme", function (assert) {
      this.theme.reset();
      assert.false(this.theme.activeThemeIsSystem);
    });
  }
);
