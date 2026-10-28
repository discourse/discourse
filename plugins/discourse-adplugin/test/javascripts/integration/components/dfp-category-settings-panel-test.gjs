import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DfpCategorySettingsPanel from "discourse/plugins/discourse-adplugin/admin/components/dfp-category-settings-panel";

module("Integration | Component | DfpCategorySettingsPanel", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the configured categories as a standard admin table", async function (assert) {
    this.settings = [
      {
        id: 1,
        category_id: 3,
        category: Category.findById(3),
        gam_adunit: "/123456789/example.com/forums",
        gam_keywords: "sports",
        gtm_taxonomy: "forums/sports",
      },
    ];

    await render(
      <template>
        <DfpCategorySettingsPanel @settings={{this.settings}} />
      </template>
    );

    assert
      .dom(".dfp-category-settings__row")
      .exists({ count: 1 }, "the saved configuration renders as a row");
    assert
      .dom(".dfp-category-settings__value")
      .includesText(
        "/123456789/example.com/forums",
        "the GAM ad unit is shown"
      );
    assert
      .dom(".dfp-category-settings__edit")
      .exists("the row has a standard edit action");
    assert
      .dom(".dfp-category-settings__delete")
      .exists("the row has a standard delete action");
  });

  test("renders the standard createable empty state", async function (assert) {
    this.settings = [];

    await render(
      <template>
        <DfpCategorySettingsPanel @settings={{this.settings}} />
      </template>
    );

    assert
      .dom(".admin-config-area-empty-list")
      .exists("the standard admin empty state is shown");
    assert
      .dom(".admin-config-area-empty-list__cta-button")
      .hasText("Add category configuration", "the create action is clear");
  });
});
