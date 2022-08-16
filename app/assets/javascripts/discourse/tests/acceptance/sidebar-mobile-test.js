import I18n from "I18n";
import { test } from "qunit";

import { click, visit } from "@ember/test-helpers";

import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Mobile - User with sidebar enabled", function (needs) {
  needs.user();

  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
  });

  needs.mobileView();

  test("hidden by default", async function (assert) {
    await visit("/");

    assert.ok(
      !exists(".sidebar-hamburger-dropdown"),
      "sidebar is not displayed"
    );
  });

  test("clicking outside sidebar collapses it", async function (assert) {
    await visit("/");

    await click(".hamburger-dropdown");

    assert.ok(exists(".sidebar-hamburger-dropdown"), "sidebar is displayed");

    await click("#main-outlet");

    assert.ok(!exists(".sidebar-hamburger-dropdown"), "sidebar is collapsed");
  });

  test("clicking on a link or button in sidebar collapses it", async function (assert) {
    await visit("/");

    await click(".hamburger-dropdown");
    await click(".sidebar-section-link-tracked");

    assert.ok(
      !exists(".sidebar-hamburger-dropdown"),
      "sidebar is collapsed when a button in sidebar is clicked"
    );

    await click(".hamburger-dropdown");
    await click(".sidebar-section-header-link");

    assert.ok(
      !exists(".sidebar-hamburger-dropdown"),
      "sidebar is collapsed when a link in sidebar is clicked"
    );
  });

  test("button to toggle between mobile and desktop view", async function (assert) {
    await visit("/");
    await click(".hamburger-dropdown");

    assert.ok(
      exists(
        `.sidebar-footer-actions-toggle-mobile-view[title="${I18n.t(
          "desktop_view"
        )}"]`
      ),
      "displays the right title for the button"
    );

    assert.ok(
      exists(".sidebar-footer-actions-toggle-mobile-view .d-icon-desktop"),
      "displays the desktop icon for the button"
    );
  });
});
