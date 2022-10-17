import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { settled, visit } from "@ember/test-helpers";
import { set } from "@ember/object";

acceptance("Bootstrap Mode Notice", function (needs) {
  needs.user();
  needs.site({ wizard_required: true });
  needs.settings({
    bootstrap_mode_enabled: true,
    bootstrap_mode_min_users: 50,
  });

  test("Navigation", async function (assert) {
    await visit("/");
    assert.ok(
      exists(".bootstrap-mode-notice"),
      "has the bootstrap mode notice"
    );

    await visit("/");
    set(this.siteSettings, "bootstrap_mode_enabled", false);
    await settled();
    assert.ok(
      !exists(".bootstrap-mode-notice"),
      "removes the notice when bootstrap mode is disabled"
    );
  });
});
