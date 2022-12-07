import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
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
    await click(".edit-2fa-backup");

    assert.ok(
      exists(".second-factor-backup-preferences"),
      "shows the 2fa backup panel"
    );

    await click(".second-factor-backup-preferences .btn-primary");

    assert.ok(exists(".backup-codes-area"), "shows backup codes");
  });

  test("delete backup codes", async function (assert) {
    updateCurrentUser({ second_factor_enabled: true });
    await visit("/u/eviltrout/preferences/second-factor");
    await click(".edit-2fa-backup");
    await click(".second-factor-backup-preferences .btn-primary");
    await click(".modal-close");
    await click(".pref-second-factor-backup .btn-danger");
    assert.strictEqual(
      query("#dialog-title").innerText.trim(),
      "Deleting backup codes"
    );
  });
});
