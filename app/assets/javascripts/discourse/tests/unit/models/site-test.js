import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Site from "discourse/models/site";

module("Unit | Model | site", function (hooks) {
  setupTest(hooks);

  test("create", function (assert) {
    const store = getOwner(this).lookup("service:store");
    assert.true(!!store.createRecord("site"), "can create with no parameters");
  });

  test("instance", function (assert) {
    const site = Site.current();

    assert.present(site, "We have a current site singleton");
    assert.present(site.categories, "The instance has a list of categories");
    assert.present(site.flagTypes, "The instance has a list of flag types");
    assert.present(site.trustLevels, "The instance has a list of trust levels");
  });

  test("create categories", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const site = store.createRecord("site", {
      categories: [
        { id: 3456, name: "Test Subcategory", parent_category_id: 1234 },
        { id: 1234, name: "Test" },
        { id: 3458, name: "Invalid Subcategory", parent_category_id: 6666 },
      ],
    });

    assert.present(site.categories, "The categories are present");
    assert.deepEqual(site.categories.mapBy("name"), [
      "Test Subcategory",
      "Test",
      "Invalid Subcategory",
    ]);

    assert.deepEqual(site.sortedCategories.mapBy("name"), [
      "Test",
      "Test Subcategory",
    ]);

    // remove invalid category and child
    site.categories.removeObject(site.categories[2]);
    site.categories.removeObject(site.categories[0]);

    assert.strictEqual(
      site.categoriesByCount.length,
      site.categories.length,
      "categoriesByCount should change on removal"
    );
    assert.strictEqual(
      site.sortedCategories.length,
      site.categories.length,
      "sortedCategories should change on removal"
    );
  });

  test("sortedCategories returns categories sorted by topic counts and sorts child categories after parent", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const site = store.createRecord("site", {
      categories: [
        {
          id: 1003,
          name: "Test Sub Sub",
          parent_category_id: 1002,
          topic_count: 0,
        },
        { id: 1001, name: "Test", topic_count: 1 },
        { id: 1004, name: "Test Sub Sub Sub", parent_category_id: 1003 },
        {
          id: 1002,
          name: "Test Sub",
          parent_category_id: 1001,
          topic_count: 0,
        },
        {
          id: 1005,
          name: "Test Sub Sub Sub2",
          parent_category_id: 1003,
          topic_count: 1,
        },
        { id: 1006, name: "Test2", topic_count: 2 },
        { id: 1000, name: "Test2 Sub", parent_category_id: 1006 },
        { id: 997, name: "Test2 Sub Sub2", parent_category_id: 1000 },
        { id: 999, name: "Test2 Sub Sub", parent_category_id: 1000 },
      ],
    });

    assert.deepEqual(site.sortedCategories.mapBy("name"), [
      "Test2",
      "Test2 Sub",
      "Test2 Sub Sub2",
      "Test2 Sub Sub",
      "Test",
      "Test Sub",
      "Test Sub Sub",
      "Test Sub Sub Sub2",
      "Test Sub Sub Sub",
    ]);
  });
});
