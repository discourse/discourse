import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import PostVotingCategorySettings from "discourse/plugins/discourse-post-voting/discourse/connectors/category-custom-settings/post-voting-category-settings";

const PARENT_ID = 1001;
const SUB_ID = 1002;
const UNRELATED_ID = 3;

function context(categories, includeSubcategories = false) {
  return {
    siteSettings: {
      post_voting_enabled_categories: categories,
      post_voting_enabled_categories_include_subcategories:
        includeSubcategories,
    },
  };
}

module("Unit | Component | PostVotingCategorySettings", function (hooks) {
  setupTest(hooks);

  test("renders for every category when unrestricted", function (assert) {
    const ctx = context("");

    assert.true(
      PostVotingCategorySettings.shouldRender(
        { category: Category.findById(PARENT_ID) },
        ctx
      ),
      "a category"
    );
    assert.true(
      PostVotingCategorySettings.shouldRender(
        { category: Category.findById(UNRELATED_ID) },
        ctx
      ),
      "another category"
    );
  });

  test("renders only for the configured categories", function (assert) {
    const ctx = context(String(PARENT_ID));

    assert.true(
      PostVotingCategorySettings.shouldRender(
        { category: Category.findById(PARENT_ID) },
        ctx
      ),
      "the configured category"
    );
    assert.false(
      PostVotingCategorySettings.shouldRender(
        { category: Category.findById(UNRELATED_ID) },
        ctx
      ),
      "a category that is not configured"
    );
    assert.false(
      PostVotingCategorySettings.shouldRender(
        { category: Category.findById(SUB_ID) },
        ctx
      ),
      "a subcategory of the configured category"
    );
  });

  test("renders for a subcategory when subcategories are included", function (assert) {
    const ctx = context(String(PARENT_ID), true);

    assert.true(
      PostVotingCategorySettings.shouldRender(
        { category: Category.findById(SUB_ID) },
        ctx
      ),
      "a subcategory of the configured category"
    );
    assert.false(
      PostVotingCategorySettings.shouldRender(
        { category: Category.findById(UNRELATED_ID) },
        ctx
      ),
      "a category outside the configured tree"
    );
  });

  test("renders for a category that has not been saved yet", function (assert) {
    const ctx = context(String(PARENT_ID));

    assert.true(
      PostVotingCategorySettings.shouldRender({ category: { id: null } }, ctx),
      "a new category has no id to check against the setting"
    );
  });
});
