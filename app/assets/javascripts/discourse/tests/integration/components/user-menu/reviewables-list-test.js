import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";

module(
  "Integration | Component | user-menu | reviewables-list",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::ReviewablesList/>`;

    test("has a 'show all' link", async function (assert) {
      await render(template);
      const showAll = query(".panel-body-bottom a.show-all");
      assert.ok(showAll.href.endsWith("/review"), "links to the /review page");
      assert.strictEqual(
        showAll.title,
        I18n.t("user_menu.reviewable.view_all"),
        "the 'show all' link has a title"
      );
    });

    test("renders a list of reviewables", async function (assert) {
      await render(template);
      const reviewables = queryAll("ul li");
      assert.strictEqual(reviewables.length, 8);
    });
  }
);
