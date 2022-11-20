import { test } from "qunit";

import { click, visit } from "@ember/test-helpers";

import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Narrow Desktop", function (needs) {
  needs.user();

  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
  });

  needs.narrowDesktopView();

  test("sidebar hidden by default", async function (assert) {
    await visit("/");

    assert.ok(!exists(".sidebar-container"), "sidebar is not displayed");
  });

  test("clicking outside sidebar collapses it", async function (assert) {
    await visit("/");

    await click(".btn-sidebar-toggle");

    assert.ok(exists(".sidebar-hamburger-dropdown"), "sidebar is displayed");

    await click("#main-outlet");

    assert.ok(!exists(".sidebar-hamburger-dropdown"), "sidebar is collapsed");
  });

  test("clicking on a link or button in sidebar collapses it", async function (assert) {
    await visit("/");

    await click(".btn-sidebar-toggle");
    await click(".sidebar-section-community .sidebar-section-header-button");

    assert.ok(
      !exists(".sidebar-hamburger-dropdown"),
      "sidebar is collapsed when a button in sidebar is clicked"
    );

    await click(".btn-sidebar-toggle");
    await click(".sidebar-section-community .sidebar-section-link-everything");

    assert.ok(
      !exists(".sidebar-hamburger-dropdown"),
      "sidebar is collapsed when a link in sidebar is clicked"
    );
  });
});
