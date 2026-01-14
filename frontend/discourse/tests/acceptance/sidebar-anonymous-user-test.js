import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Sidebar - Anonymous User", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
  });

  test("sidebar is displayed", async function (assert) {
    await visit("/");

    assert
      .dom(document.body)
      .hasClass("has-sidebar-page", "adds sidebar utility class to body");

    assert
      .dom(".sidebar-container")
      .exists("sidebar exists for anonymous user");

    assert
      .dom(".header-sidebar-toggle")
      .exists("toggle button for anonymous user");
  });

  test("sidebar hamburger panel dropdown when sidebar has been disabled", async function (assert) {
    this.siteSettings.navigation_menu = "header dropdown";

    await visit("/");
    await click(".hamburger-dropdown button");

    assert
      .dom(".sidebar-hamburger-dropdown .sidebar-sections-anonymous")
      .exists(
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

    assert
      .dom(".sidebar-container")
      .doesNotExist("sidebar is hidden for anonymous user");

    assert
      .dom(".header-sidebar-toggle")
      .doesNotExist("toggle button is hidden for anonymous user");
  });
});
