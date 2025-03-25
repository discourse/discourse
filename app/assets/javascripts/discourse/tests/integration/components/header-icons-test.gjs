import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { SEARCH_BUTTON_ID } from "discourse/components/header";
import Icons from "discourse/components/header/icons";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Header | Icons", function (hooks) {
  setupRenderingTest(hooks);

  test("showSearchButton", async function (assert) {
    const site = getOwner(this).lookup("service:site");
    const noop = () => {};
    this.siteSettings.search_experience = "search_field";

    await render(
      <template>
        <Icons
          @sidebarEnabled={{true}}
          @toggleSearchMenu={{noop}}
          @toggleNavigationMenu={{noop}}
          @toggleUserMenu={{noop}}
          @searchButtonId={{SEARCH_BUTTON_ID}}
        />
      </template>
    );

    assert
      .dom(".search-dropdown")
      .doesNotExist(
        "it does not display when the search_experience setting is search_field"
      );

    this.siteSettings.search_experience = "search_icon";

    await render(
      <template>
        <Icons
          @sidebarEnabled={{true}}
          @toggleSearchMenu={{noop}}
          @toggleNavigationMenu={{noop}}
          @toggleUserMenu={{noop}}
          @searchButtonId={{SEARCH_BUTTON_ID}}
        />
      </template>
    );

    assert
      .dom(".search-dropdown")
      .exists(
        "it does display when the search_experience setting is search_icon"
      );

    sinon.stub(site, "mobileView").value(true);
    this.siteSettings.search_experience = "search_field";

    await render(
      <template>
        <Icons
          @sidebarEnabled={{true}}
          @toggleSearchMenu={{noop}}
          @toggleNavigationMenu={{noop}}
          @toggleUserMenu={{noop}}
          @searchButtonId={{SEARCH_BUTTON_ID}}
        />
      </template>
    );

    assert
      .dom(".search-dropdown")
      .exists(
        "it does display when the site is in mobile view even if search_experience setting is search_field"
      );

    sinon.stub(site, "mobileView").value(false);
    this.siteSettings.search_experience = "search_icon";

    withPluginApi("1.37.1", (api) => {
      api.registerValueTransformer("site-setting-search-experience", () => {
        return "search_field";
      });
    });

    await render(
      <template>
        <Icons
          @sidebarEnabled={{true}}
          @toggleSearchMenu={{noop}}
          @toggleNavigationMenu={{noop}}
          @toggleUserMenu={{noop}}
          @searchButtonId={{SEARCH_BUTTON_ID}}
        />
      </template>
    );

    assert
      .dom(".search-dropdown")
      .doesNotExist(
        "it does not display when the value transformer is not search_icon"
      );
  });
});
