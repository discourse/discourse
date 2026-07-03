import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewablesList from "discourse/components/user-menu/reviewables-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module(
  "Integration | Component | UserMenu | ReviewablesList",
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
      assert.dom("ul li").exists({ count: 8 });
    });
  }
);
