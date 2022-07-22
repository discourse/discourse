import { test } from "qunit";
import { click, currentRouteName, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { undockSidebar } from "discourse/tests/helpers/sidebar-helpers";

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
    await click(".sidebar-footer-actions-keyboard-shortcuts");

    assert.ok(
      exists("#keyboard-shortcuts-help"),
      "keyboard shortcuts help is displayed"
    );
  });

  test("navigating to site setting route using sidebar", async function (assert) {
    await visit("/");
    await click(".sidebar-footer-link-site-settings");

    assert.strictEqual(currentRouteName(), "adminSiteSettingsCategory");
  });

  test("site setting link is not shown in sidebar for non-admin user", async function (assert) {
    updateCurrentUser({ admin: false });

    await visit("/");

    assert.notOk(exists(".sidebar-footer-link-site-settings"));
  });

  test("undocking and docking sidebar", async function (assert) {
    await visit("/");

    assert.ok(
      document.body.classList.contains("has-sidebar-page"),
      "adds sidebar utility class to body"
    );

    assert.ok(exists(".sidebar-container"), "displays the sidebar by default");

    await undockSidebar();

    assert.ok(
      !document.body.classList.contains("has-sidebar-page"),
      "removes sidebar utility class from body"
    );

    assert.ok(!exists(".sidebar-container"), "hides the sidebar");

    await click(".hamburger-dropdown");

    assert.ok(
      exists(".sidebar-hamburger-dropdown"),
      "displays the sidebar in hamburger dropdown"
    );

    await click("button.sidebar-footer-actions-dock-toggle");

    assert.ok(
      exists(".sidebar-container"),
      "displays the sidebar after docking"
    );
  });
});
