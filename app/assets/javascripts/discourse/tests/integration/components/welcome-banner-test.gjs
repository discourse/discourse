import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import WelcomeBanner from "discourse/components/welcome-banner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | WelcomeBanner", function (hooks) {
  setupRenderingTest(hooks);

  test("shouldDisplay", async function (assert) {
    const router = getOwner(this).lookup("service:router");

    await render(<template><WelcomeBanner /></template>);
    assert
      .dom(".welcome-banner")
      .doesNotExist("it does not display when the site setting is disabled");

    this.siteSettings.enable_welcome_banner = true;

    await render(<template><WelcomeBanner /></template>);
    assert
      .dom(".welcome-banner")
      .doesNotExist(
        "it does not dispaly when the site setting is enabled but the route is not correct"
      );

    sinon.stub(router, "currentRouteName").value("discovery.latest");
    await render(<template><WelcomeBanner /></template>);
    assert
      .dom(".welcome-banner")
      .exists(
        "it does dispaly when the site setting is enabled and the route is correct from top_menu"
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
});
