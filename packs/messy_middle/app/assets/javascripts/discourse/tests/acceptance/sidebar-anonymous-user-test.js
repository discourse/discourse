import { test } from "qunit";

import { click, visit } from "@ember/test-helpers";

import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anonymous User", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
  });

  test("sidebar is displayed", async function (assert) {
    await visit("/");

    assert.ok(
      document.body.classList.contains("has-sidebar-page"),
      "adds sidebar utility class to body"
    );

    assert.ok(
      exists(".sidebar-container"),
      "sidebar exists for anonymous user"
    );

    assert.ok(
      exists(".header-sidebar-toggle"),
      "toggle button for anonymous user"
    );
  });

  test("sidebar hamburger panel dropdown when sidebar has been disabled", async function (assert) {
    this.siteSettings.navigation_menu = "header dropdown";

    await visit("/");
    await click(".hamburger-dropdown");

    assert.ok(
      exists(".sidebar-hamburger-dropdown .sidebar-sections-anonymous"),
      "sidebar hamburger panel dropdown renders anonymous sidebar sections"
    );
  });
});

acceptance("Sidebar - Anonymous User - Login Required", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
    login_required: true,
  });

  test("sidebar and toggle button is hidden", async function (assert) {
    await visit("/");

    assert.ok(
      !exists(".sidebar-container"),
      "sidebar is hidden for anonymous user"
    );

    assert.ok(
      !exists(".header-sidebar-toggle"),
      "toggle button is hidden for anonymous user"
    );
  });
});
