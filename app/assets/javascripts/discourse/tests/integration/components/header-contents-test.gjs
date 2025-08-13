import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Contents from "discourse/components/header/contents";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Header | Contents", function (hooks) {
  setupRenderingTest(hooks);

  module("header search", function () {
    test("is hidden in mobile view", async function (assert) {
      const site = getOwner(this).lookup("service:site");
      const toggleNavigationMenu = () => {};

      sinon.stub(site, "mobileView").value(false);

      await render(
        <template>
          <Contents
            @sidebarEnabled={{true}}
            @toggleNavigationMenu={{toggleNavigationMenu}}
            @showSidebar={{true}}
          >
            test
          </Contents>
        </template>
      );

      assert
        .dom(".floating-search-input-wrapper")
        .doesNotExist("it does not display when the site is in mobile view");
    });

    ["signup", "login", "invites.show", "activate-account"].forEach((name) => {
      test(`is hidden in route "${name}"`, async function (assert) {
        const router = getOwner(this).lookup("service:router");
        const toggleNavigationMenu = () => {};

        sinon.stub(router, "currentRouteName").value(name);

        await render(
          <template>
            <Contents
              @sidebarEnabled={{true}}
              @toggleNavigationMenu={{toggleNavigationMenu}}
              @showSidebar={{true}}
            >
              {{router.currentRouteName}}
            </Contents>
          </template>
        );

        assert
          .dom(".floating-search-input-wrapper")
          .doesNotExist(`it does not display on "${name}" route`);
      });
    });

    ["login-preferences", "badges.show"].forEach((name) => {
      test(`is shown in route "${name}"`, async function (assert) {
        const router = getOwner(this).lookup("service:router");
        const toggleNavigationMenu = () => {};

        sinon.stub(router, "currentRouteName").value(name);

        await render(
          <template>
            <Contents
              @sidebarEnabled={{true}}
              @toggleNavigationMenu={{toggleNavigationMenu}}
              @showSidebar={{true}}
            >
              {{router.currentRouteName}}
            </Contents>
          </template>
        );

        assert
          .dom(".floating-search-input-wrapper")
          .exists(`it is shown on "${name}" route`);
      });
    });
  });
});
