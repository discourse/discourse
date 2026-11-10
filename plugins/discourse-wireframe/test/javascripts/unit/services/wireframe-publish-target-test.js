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

    test("hasDesign is false until the session is bound to a design component", function (assert) {
      this.theme.setActiveTheme(7);
      assert.false(this.theme.hasDesign);
      this.theme.registerDesign(8, "Spring launch");
      this.theme.setActiveTheme(8);
      assert.true(this.theme.hasDesign);
      assert.strictEqual(
        this.theme.activeThemeTarget.themeName,
        "Spring launch"
      );
    });
  }
);
