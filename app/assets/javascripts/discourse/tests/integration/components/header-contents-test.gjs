import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Contents from "discourse/components/header/contents";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Header | Contents", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.router = getOwner(this).lookup("service:router");
    const search = getOwner(this).lookup("service:search");
    sinon.stub(search, "searchExperience").value("search_field");
  });

  hooks.afterEach(function () {
    sinon.restore(); // clean up all stubs
  });

  module("header search", function () {
    test("is hidden in mobile view", async function (assert) {
      const site = getOwner(this).lookup("service:site");
      sinon.stub(site, "mobileView").value(true);

      await render(<template><Contents /></template>);

      assert
        .dom(".floating-search-input-wrapper")
        .doesNotExist("it does not display when the site is in mobile view");
    });

    module("routes handling", function () {
      test('is hidden in route "signup"', async function (assert) {
        sinon.stub(this.router, "currentRouteName").value("signup");

        await render(<template><Contents /></template>);

        assert
          .dom(".floating-search-input-wrapper")
          .doesNotExist('it does not display on route: "signup"');
      });

      test('is hidden in route "login"', async function (assert) {
        sinon.stub(this.router, "currentRouteName").value("login");

        await render(<template><Contents /></template>);

        assert
          .dom(".floating-search-input-wrapper")
          .doesNotExist('it does not display on route: "login"');
      });

      test('is hidden in route "invites.show"', async function (assert) {
        sinon.stub(this.router, "currentRouteName").value("invites.show");

        await render(<template><Contents /></template>);

        assert
          .dom(".floating-search-input-wrapper")
          .doesNotExist('it does not display on route: "invites.show"');
      });

      test('is hidden in route "activate-account"', async function (assert) {
        sinon.stub(this.router, "currentRouteName").value("activate-account");

        await render(<template><Contents /></template>);

        assert
          .dom(".floating-search-input-wrapper")
          .doesNotExist('it does not display on route: "activate-account"');
      });

      test('is shown in route "login-preferences"', async function (assert) {
        sinon.stub(this.router, "currentRouteName").value("login-preferences");

        await render(<template><Contents /></template>);

        assert
          .dom(".floating-search-input-wrapper")
          .exists('it is shown on route: "login-preferences"');
      });

      test('is shown in route "badges.show"', async function (assert) {
        sinon.stub(this.router, "currentRouteName").value("badges.show");

        await render(<template><Contents /></template>);

        assert
          .dom(".floating-search-input-wrapper")
          .exists('it is shown on route: "badges.show"');
      });
    });
  });
});
