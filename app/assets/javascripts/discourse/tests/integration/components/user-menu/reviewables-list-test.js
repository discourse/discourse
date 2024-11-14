import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

module(
  "Integration | Component | user-menu | reviewables-list",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::ReviewablesList/>`;

    test("show all button for reviewable notifications", async function (assert) {
      await render(template);
      assert
        .dom(".panel-body-bottom .show-all")
        .hasAttribute(
          "title",
          I18n.t("user_menu.reviewable.view_all"),
          "has the correct title"
        );
    });

    test("renders a list of reviewables", async function (assert) {
      await render(template);
      const reviewables = queryAll("ul li");
      assert.strictEqual(reviewables.length, 8);
    });
  }
);
