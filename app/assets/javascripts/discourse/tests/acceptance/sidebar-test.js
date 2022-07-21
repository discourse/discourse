import { test } from "qunit";
import { click, currentRouteName, visit } from "@ember/test-helpers";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
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
    await click(".sidebar-footer-link-keyboard-shortcuts");

    assert.ok(
      exists("#keyboard-shortcuts-help"),
      "keyboard shortcuts help is displayed"
    );
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
