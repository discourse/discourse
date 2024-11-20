import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Admin - Badges - Mass Award", function (needs) {
  needs.user();
  test("when the badge can be granted multiple times", async function (assert) {
    await visit("/admin/badges/award/new");
    await click(
      '.admin-badge-list-item span[data-badge-name="Both image and icon"]'
    );
    assert.strictEqual(
      query("label.grant-existing-holders").textContent.trim(),
      i18n("admin.badges.mass_award.grant_existing_holders"),
      "checkbox for granting existing holders is displayed"
    );
  });

  test("when the badge can not be granted multiple times", async function (assert) {
    await visit("/admin/badges/award/new");
    await click('.admin-badge-list-item span[data-badge-name="Only icon"]');
    assert
      .dom(".grant-existing-holders")
      .doesNotExist("checkbox for granting existing holders is not displayed");
  });
});
