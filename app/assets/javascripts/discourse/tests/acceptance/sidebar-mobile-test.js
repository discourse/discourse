import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Mobile - User with sidebar enabled", function (needs) {
  needs.user({ experimental_sidebar_enabled: true });
  needs.mobileView();

  test("hidden by default", async function (assert) {
    await visit("/");

    assert.ok(!exists(".sidebar-container"), "sidebar is not displayed");
  });

  test("clicking outside sidebar collapses it", async function (assert) {
    await visit("/");

    await click(".hamburger-dropdown");

    assert.notOk(
      exists(".sidebar-footer-actions-dock-toggle"),
      "button to dock sidebar is not displayed"
    );

    assert.ok(exists(".sidebar-container"), "sidebar is displayed");

    await click("#main-outlet");

    assert.ok(!exists(".sidebar-container"), "sidebar is collapsed");
  });

  test("clicking on a link or button in sidebar collapses it", async function (assert) {
    await visit("/");

    await click(".hamburger-dropdown");
    await click(".sidebar-section-link-tracked");

    assert.ok(
      !exists(".sidebar-container"),
      "sidebar is collapsed when a button in sidebar is clicked"
    );

    await click(".hamburger-dropdown");
    await click(".sidebar-section-header-link");

    assert.ok(
      !exists(".sidebar-container"),
      "sidebar is collapsed when a link in sidebar is clicked"
    );
  });

  test("sidebar sections are not collapsible on mobile", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown");

    assert.notOk(exists(".sidebar-section-header-caret"));
  });
});
