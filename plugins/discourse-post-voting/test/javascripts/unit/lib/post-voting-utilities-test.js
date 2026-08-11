import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import { postVotingEnabledForCategory } from "discourse/plugins/discourse-post-voting/discourse/lib/post-voting-utilities";

const PARENT_ID = 1001;
const SUB_ID = 1002;
const NESTED_SUB_ID = 1003;
const UNRELATED_ID = 3;

module("Unit | Lib | post-voting-utilities", function (hooks) {
  setupTest(hooks);

  function settings(categories, includeSubcategories = false) {
    return {
      post_voting_enabled_categories: categories,
      post_voting_enabled_categories_include_subcategories:
        includeSubcategories,
    };
  }

  test("postVotingEnabledForCategory allows every category when unrestricted", function (assert) {
    const category = Category.findById(PARENT_ID);

    assert.true(
      postVotingEnabledForCategory(category, settings("")),
      "an empty setting"
    );
    assert.true(
      postVotingEnabledForCategory(category, settings(null)),
      "a missing setting"
    );
    assert.true(
      postVotingEnabledForCategory(null, settings("")),
      "no category chosen yet"
    );
  });

  test("postVotingEnabledForCategory allows only the configured categories", function (assert) {
    const configured = settings(`${PARENT_ID}|${UNRELATED_ID}`);

    assert.true(
      postVotingEnabledForCategory(Category.findById(PARENT_ID), configured),
      "the first configured category"
    );
    assert.true(
      postVotingEnabledForCategory(Category.findById(UNRELATED_ID), configured),
      "the last configured category"
    );
    assert.false(
      postVotingEnabledForCategory(Category.findById(SUB_ID), configured),
      "a category that is not configured"
    );
  });

  test("postVotingEnabledForCategory excludes subcategories by default", function (assert) {
    const configured = settings(String(PARENT_ID));

    assert.false(
      postVotingEnabledForCategory(Category.findById(SUB_ID), configured),
      "a subcategory of a configured category"
    );
    assert.false(
      postVotingEnabledForCategory(
        Category.findById(NESTED_SUB_ID),
        configured
      ),
      "a deeply nested subcategory of a configured category"
    );
  });

  test("postVotingEnabledForCategory includes descendants when subcategories are included", function (assert) {
    const configured = settings(String(PARENT_ID), true);

    assert.true(
      postVotingEnabledForCategory(Category.findById(PARENT_ID), configured),
      "the configured category itself"
    );
    assert.true(
      postVotingEnabledForCategory(Category.findById(SUB_ID), configured),
      "a subcategory"
    );
    assert.true(
      postVotingEnabledForCategory(
        Category.findById(NESTED_SUB_ID),
        configured
      ),
      "a deeply nested subcategory"
    );
    assert.false(
      postVotingEnabledForCategory(Category.findById(UNRELATED_ID), configured),
      "a category outside the configured tree"
    );
  });

  test("postVotingEnabledForCategory does not treat a parent as configured by its subcategory", function (assert) {
    const configured = settings(String(SUB_ID), true);

    assert.false(
      postVotingEnabledForCategory(Category.findById(PARENT_ID), configured),
      "the parent of a configured subcategory"
    );
    assert.true(
      postVotingEnabledForCategory(
        Category.findById(NESTED_SUB_ID),
        configured
      ),
      "a descendant of a configured subcategory"
    );
  });

  test("postVotingEnabledForCategory matches category ids exactly", function (assert) {
    assert.false(
      postVotingEnabledForCategory(Category.findById(12), settings("1")),
      "does not match a longer id sharing a prefix"
    );
    assert.false(
      postVotingEnabledForCategory(Category.findById(1), settings("12")),
      "does not match a shorter id sharing a prefix"
    );
  });

  test("postVotingEnabledForCategory rejects a missing category when restricted", function (assert) {
    assert.false(
      postVotingEnabledForCategory(null, settings(String(PARENT_ID))),
      "a null category"
    );
    assert.false(
      postVotingEnabledForCategory(undefined, settings(String(PARENT_ID))),
      "an undefined category"
    );
  });
});
