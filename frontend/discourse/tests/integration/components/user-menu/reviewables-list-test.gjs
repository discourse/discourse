import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewablesList from "discourse/components/user-menu/reviewables-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | user-menu | reviewables-list",
  function (hooks) {
    setupRenderingTest(hooks);

    test("show all button for reviewable notifications", async function (assert) {
      await render(<template><ReviewablesList /></template>);
      assert
        .dom(".panel-body-bottom .show-all")
        .hasAttribute(
          "title",
          i18n("user_menu.reviewable.view_all"),
          "has the correct title"
        );
    });

    test("renders a list of reviewables", async function (assert) {
      await render(<template><ReviewablesList /></template>);
      const reviewables = queryAll("ul li");
      assert.strictEqual(reviewables.length, 8);
    });
  }
);
