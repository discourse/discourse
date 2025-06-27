import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import WelcomeBanner from "discourse/components/welcome-banner";
import LocalizationInitializer from "discourse/instance-initializers/localization";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n, { i18n } from "discourse-i18n";

module("Integration | Component | WelcomeBanner", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this._overrides = I18n._overrides;
    this.router = getOwner(this).lookup("service:router");
  });

  hooks.afterEach(function () {
    I18n._overrides = this._overrides;
  });

  test("shouldDisplay", async function (assert) {
    await render(<template><WelcomeBanner /></template>);
    assert
      .dom(".welcome-banner")
      .doesNotExist("it does not display when the site setting is disabled");

    this.siteSettings.enable_welcome_banner = true;

    await render(<template><WelcomeBanner /></template>);
    assert
      .dom(".welcome-banner")
      .doesNotExist(
        "it does not display when the site setting is enabled but the route is not correct"
      );

    sinon.stub(this.router, "currentRouteName").value("discovery.latest");
    await render(<template><WelcomeBanner /></template>);
    assert
      .dom(".welcome-banner")
      .exists(
        "it does display when the site setting is enabled and the route is correct from top_menu"
      );

    withPluginApi("1.37.1", (api) => {
      api.registerValueTransformer("site-setting-enable-welcome-banner", () => {
        return false;
      });
    });

    await render(<template><WelcomeBanner /></template>);
    assert
      .dom(".welcome-banner")
      .doesNotExist(
        "it does not display when the value transformer returns a different value from the site setting"
      );
  });

  test("optional subheader", async function (assert) {
    sinon.stub(this.router, "currentRouteName").value("discovery.latest");
    I18n._overrides = {
      en: {
        js: {
          welcome_banner: {
            subheader: {
              logged_in_members: "",
            },
          },
        },
      },
    };
    LocalizationInitializer.initialize(this.owner);

    await render(<template><WelcomeBanner /></template>);

    assert
      .dom(".welcome-banner__subheader")
      .doesNotExist("should not be rendered when text is empty");

    I18n.translations.en.js.welcome_banner.subheader.logged_in_members =
      "Logged in members can see this subheader";

    await render(<template><WelcomeBanner /></template>);

    assert
      .dom(".welcome-banner__subheader")
      .isVisible("should be rendered if text is provided")
      .hasText(
        i18n("welcome_banner.subheader.logged_in_members"),
        "should contain proper text"
      );
  });
});
