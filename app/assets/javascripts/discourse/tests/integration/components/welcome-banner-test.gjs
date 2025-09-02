import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import WelcomeBanner from "discourse/components/welcome-banner";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | WelcomeBanner | Logged in user",
  function (hooks) {
    setupRenderingTest(hooks, { stubRouter: true });

    test("hides when enable_welcome_banner is false", async function (assert) {
      this.siteSettings.enable_welcome_banner = false;
      await render(<template><WelcomeBanner /></template>);
      assert.dom(".welcome-banner").doesNotExist("banner is not rendered");
    });

    test("applies the welcome_banner_location CSS class", async function (assert) {
      this.siteSettings.welcome_banner_location = "above_topic_content";
      await render(<template><WelcomeBanner /></template>);
      assert.dom(".welcome-banner.--location-above-topic-content").exists();

      this.siteSettings.welcome_banner_location = "below_site_header";
      await render(<template><WelcomeBanner /></template>);
      assert.dom(".welcome-banner.--location-below-site-header").exists();
    });

    test("shows the logged in user message with the user's username", async function (assert) {
      await render(<template><WelcomeBanner /></template>);

      assert.dom(".welcome-banner").containsText(
        i18n("welcome_banner.header.logged_in_members", {
          preferred_display_name: "eviltrout",
        }),
        "banner contains the correct message for logged in users with username"
      );
    });

    test("shows the logged in user message with the user's display name", async function (assert) {
      this.siteSettings.display_name_on_posts = true;
      this.siteSettings.prioritize_username_in_ux = false;

      await render(<template><WelcomeBanner /></template>);

      assert.dom(".welcome-banner").containsText(
        i18n("welcome_banner.header.logged_in_members", {
          preferred_display_name: "Robin Ward",
        }),
        "banner contains the correct message for logged in users with username"
      );

      this.currentUser.name = "<input type='text'></input>Robin Ward";
      await render(<template><WelcomeBanner /></template>);

      assert.dom(".welcome-banner").containsText(
        i18n("welcome_banner.header.logged_in_members", {
          preferred_display_name: "Robin Ward",
        }),
        "banner contains the correct message for logged in users with username"
      );
      assert.dom(".welcome-banner .welcome-banner__title input").doesNotExist();
    });

    test("uses the welcome_banner.search translation for placeholder", async function (assert) {
      await render(<template><WelcomeBanner /></template>);

      assert
        .dom("#welcome-banner-search-input")
        .hasAttribute(
          "placeholder",
          i18n("welcome_banner.search"),
          "search input uses the welcome_banner.search translation as placeholder"
        );
    });
  }
);

module(
  "Integration | Component | WelcomeBanner | Anonymous user",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true, stubRouter: true });

    test("shows the anonymous user message with the site name", async function (assert) {
      this.siteSettings.title = "Test Banner Site";

      await render(<template><WelcomeBanner /></template>);

      assert
        .dom(".welcome-banner")
        .exists("banner is rendered for anonymous users");
      assert.dom(".welcome-banner").containsText(
        i18n("welcome_banner.header.anonymous_members", {
          site_name: "Test Banner Site",
        }),
        "banner contains the correct message for anonymous users"
      );
    });
  }
);
