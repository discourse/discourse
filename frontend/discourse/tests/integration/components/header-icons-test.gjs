import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { SEARCH_BUTTON_ID } from "discourse/components/header";
import Icons from "discourse/components/header/icons";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Header | Icons", function (hooks) {
  setupRenderingTest(hooks);

  test("showSearchButton", async function (assert) {
    const siteStub = sinon.stub(
      getOwner(this).lookup("service:site"),
      "mobileView"
    );
    const routerStub = sinon.stub(
      getOwner(this).lookup("service:router"),
      "currentRouteName"
    );
    const noop = () => {};
    this.siteSettings.search_experience = "search_field";
    routerStub.value("discovery.latest");

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

    routerStub.value("admin.dashboard.general");

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
        "it shows on admin routes even when the search_experience setting is search_field"
      );

    this.siteSettings.search_experience = "search_icon";
    routerStub.value("discovery.latest");

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

    this.siteSettings.search_experience = "search_field";
    siteStub.value(true);

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
  });
});
