import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  lookupAdminDashboardSection,
  registerAdminDashboardSection,
  resetAdminDashboardSections,
} from "discourse/admin/lib/admin-dashboard-sections";

module("Unit | Lib | admin-dashboard-sections", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    resetAdminDashboardSections();
  });

  test("looks up a component registered for a section id", function (assert) {
    class SupportSection {}
    registerAdminDashboardSection("support", SupportSection);

    assert.strictEqual(lookupAdminDashboardSection("support"), SupportSection);
  });

  test("returns undefined for an unregistered id", function (assert) {
    assert.strictEqual(lookupAdminDashboardSection("missing"), undefined);
  });

  test("reset clears registrations", function (assert) {
    registerAdminDashboardSection("support", class {});
    resetAdminDashboardSections();

    assert.strictEqual(lookupAdminDashboardSection("support"), undefined);
  });
});
