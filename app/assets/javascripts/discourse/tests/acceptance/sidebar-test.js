import I18n from "I18n";

import { test } from "qunit";
import { click, currentRouteName, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anon User", function () {
  // Don't show sidebar for anon user until we know what we want to display
  test("sidebar is not displayed", async function (assert) {
    await visit("/");

    assert.ok(
      !document.body.classList.contains("has-sidebar-page"),
      "does not add sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-container"));
  });
});

acceptance("Sidebar - User with sidebar disabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: false });

  test("sidebar is not displayed", async function (assert) {
    await visit("/");

    assert.ok(
      !document.body.classList.contains("has-sidebar-page"),
      "does not add sidebar utility class to body"
    );

    assert.ok(!exists(".sidebar-container"));
  });
});

acceptance("Sidebar - User with sidebar enabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });

  test("navigating to about route using sidebar", async function (assert) {
    await visit("/");
    await click(".sidebar-footer-link-about");

    assert.strictEqual(currentRouteName(), "about");
  });

  test("viewing keyboard shortcuts using sidebar", async function (assert) {
    await visit("/");
    await click(
      `.sidebar-footer-actions-keyboard-shortcuts[title="${I18n.t(
        "keyboard_shortcuts_help.title"
      )}"]`
    );

    assert.ok(
      exists("#keyboard-shortcuts-help"),
      "keyboard shortcuts help is displayed"
    );
  });

  test("navigating to admin route using sidebar", async function (assert) {
    await visit("/");
    await click(".sidebar-footer-link-admin");

    assert.strictEqual(currentRouteName(), "admin.dashboard.general");
  });

  test("admin link is not shown in sidebar for non-admin user", async function (assert) {
    updateCurrentUser({ admin: false, moderator: false });

    await visit("/");

    assert.notOk(exists(".sidebar-footer-link-admin"));
  });
});
