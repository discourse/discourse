import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

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

acceptance(
  "Sidebar - Anonymous User - Mobile hamburger sign up",
  function (needs) {
    needs.mobileView();

    test("shows sign up as the first item in the hamburger menu", async function (assert) {
      await visit("/");
      await click(".hamburger-dropdown button");

      const signUpLabel = i18n("sign_up");

      assert
        .dom(
          `.sidebar-hamburger-dropdown button[data-list-item-name="${signUpLabel}"]`
        )
        .exists("sign up link is shown in the hamburger menu");

      await click(
        `.sidebar-hamburger-dropdown button[data-list-item-name="${signUpLabel}"]`
      );

      assert.dom(".signup-fullpage").exists("it shows the signup page");
    });
  }
);

acceptance(
  "Sidebar - Anonymous User - Desktop hamburger sign up",
  function (needs) {
    needs.settings({
      navigation_menu: "header dropdown",
    });

    test("does not show sign up in the hamburger menu on desktop", async function (assert) {
      await visit("/");
      await click(".hamburger-dropdown button");

      const signUpLabel = i18n("sign_up");

      assert
        .dom(
          `.sidebar-hamburger-dropdown button[data-list-item-name="${signUpLabel}"]`
        )
        .doesNotExist("sign up link is hidden on desktop");
    });
  }
);

acceptance(
  "Sidebar - Anonymous User - Invite only hamburger sign up",
  function (needs) {
    needs.mobileView();
    needs.settings({
      invite_only: true,
    });

    test("does not show sign up in the hamburger menu when invite only", async function (assert) {
      await visit("/");
      await click(".hamburger-dropdown button");

      const signUpLabel = i18n("sign_up");

      assert
        .dom(
          `.sidebar-hamburger-dropdown button[data-list-item-name="${signUpLabel}"]`
        )
        .doesNotExist("sign up link is hidden when invite only");
    });
  }
);

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
