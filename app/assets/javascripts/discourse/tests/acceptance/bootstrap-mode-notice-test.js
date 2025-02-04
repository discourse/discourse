import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Bootstrap Mode Notice", function (needs) {
  needs.user({ admin: true });
  needs.site({ wizard_required: true });
  needs.settings({
    bootstrap_mode_enabled: true,
    bootstrap_mode_min_users: 50,
  });

  test("is displayed if bootstrap mode is enabled", async function (assert) {
    this.siteSettings.bootstrap_mode_enabled = true;
    await visit("/");
    assert.dom(".bootstrap-mode").exists();
  });

  test("is hidden if bootstrap mode is disabled", async function (assert) {
    this.siteSettings.bootstrap_mode_enabled = false;
    await visit("/");
    assert.dom(".bootstrap-mode").doesNotExist();
  });
});
