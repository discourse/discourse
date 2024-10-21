import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("User Preferences - Second Factor Backup", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.post("/u/second_factors.json", () => {
      return helper.response({
        success: "OK",
        totps: [{ id: 1, name: "one of them" }],
      });
    });

    server.put("/u/second_factors_backup.json", () => {
      return helper.response({
        backup_codes: ["dsffdsd", "fdfdfdsf", "fddsds"],
      });
    });

    server.get("/u/eviltrout/activity.json", () => {
      return helper.response({});
    });
  });

  test("second factor backup", async function (assert) {
    updateCurrentUser({ second_factor_enabled: true });
    await visit("/u/eviltrout/preferences/second-factor");
    await click(".new-second-factor-backup");

    assert.ok(
      exists(".second-factor-backup-edit-modal"),
      "shows the 2fa backup panel"
    );

    await click(".second-factor-backup-edit-modal .btn-primary");

    assert.ok(exists(".backup-codes-area"), "shows backup codes");
  });

  test("delete backup codes", async function (assert) {
    updateCurrentUser({ second_factor_enabled: true });
    await visit("/u/eviltrout/preferences/second-factor");

    // create backup codes
    await click(".new-second-factor-backup");
    await click(".second-factor-backup-edit-modal .btn-primary");
    await click(".second-factor-backup-edit-modal .modal-close");

    await click(".two-factor-backup-dropdown .select-kit-header");
    await click("li[data-name='Disable']");
    assert.dom("#dialog-title").hasText("Deleting backup codes");
  });
});
