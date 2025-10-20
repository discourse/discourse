import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withSilencedDeprecations } from "discourse/lib/deprecated";
import PreloadStore from "discourse/lib/preload-store";
import CategoryList from "discourse/models/category-list";
import Site from "discourse/models/site";
import Topic from "discourse/models/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

module("Unit | Model | CategoryList", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  test("categoriesFrom creates categories from API result", function (assert) {
    const result = {
      category_list: {
        categories: [
          {
            id: 1,
            name: "General",
            topics_week: 5,
            topics_month: 20,
            topics_all_time: 100,
            parent_category_id: null,
          },
          {
            id: 2,
            name: "Support",
            topics_week: 0,
            topics_month: 3,
            topics_all_time: 50,
            parent_category_id: null,
          },
        ],
      },
    };

    const categoryList = CategoryList.categoriesFrom(this.store, result);

    assert.true(categoryList instanceof CategoryList);
    assert.strictEqual(
      categoryList.content.length,
      2,
      ".content provides clean access to the array"
    );

    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        assert.strictEqual(categoryList.length, 2, "proxy length works");
      }
    );
  });

  test("categoriesFrom filters categories by parent category", function (assert) {
    const parentCategory = { id: 1 };
    const result = {
      category_list: {
        categories: [
          {
            id: 2,
            name: "Child Category",
            parent_category_id: 1,
            topics_all_time: 10,
          },
          {
            id: 3,
            name: "Other Category",
            parent_category_id: 2,
            topics_all_time: 15,
          },
        ],
      },
    };

    const categoryList = CategoryList.categoriesFrom(
      this.store,
      result,
      parentCategory
    );

    assert.strictEqual(categoryList.content.length, 1);

    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        assert.strictEqual(categoryList.length, 1, "proxy length works");
      }
    );
  });

  test("categoriesFrom handles empty category list", function (assert) {
    const result = { category_list: { categories: [] } };
    const categoryList = CategoryList.categoriesFrom(this.store, result);

    assert.true(categoryList instanceof CategoryList);
    assert.strictEqual(categoryList.content.length, 0);
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        assert.strictEqual(categoryList.length, 0, "proxy length works");
      }
    );
  });

  test("array methods on .content work and do not warn", function (assert) {
    const categoryList = CategoryList.create({ categories: [] });
    categoryList.content.push({ id: 1 });
    assert.strictEqual(categoryList.content.length, 1);
    categoryList.content.splice(0, 1);
    assert.strictEqual(categoryList.content.length, 0);
  });

  test("_buildCategoryResult builds category with week stats", function (assert) {
    const rawData = {
      id: 1,
      topics_week: 10,
      topics_month: 20,
      topics_all_time: 100,
    };

    const result = CategoryList._buildCategoryResult(rawData, "week");

    assert.true(result.stat.includes("10"));
    assert.true(result.stat.includes("value"));
    assert.strictEqual(
      result.statTitle,
      i18n(`categories.topic_stat_sentence_week`, {
        count: rawData.topics_week,
      })
    );
    assert.false(result.pickAll);
  });

  test("_buildCategoryResult builds category with all-time stats when no recent activity", function (assert) {
    const rawData = {
      id: 1,
      topics_week: 0,
      topics_month: 0,
      topics_all_time: 50,
    };

    const result = CategoryList._buildCategoryResult(rawData, "week");

    assert.true(result.stat.includes("50"));
    assert.true(result.pickAll);
  });

  test("_buildCategoryResult processes topics array", function (assert) {
    const rawData = {
      id: 1,
      topics: [{ id: 1, title: "Test Topic" }],
      topics_all_time: 10,
    };

    const result = CategoryList._buildCategoryResult(rawData, "all");

    assert.strictEqual(result.topics.length, 1);
    assert.true(result.topics[0] instanceof Topic);
  });

  test("_buildCategoryResult adds mobile stats", function (assert) {
    const originalSiteCurrent = Site.current;
    Site.current = () => ({
      updateCategory: (category) => {
        category.setupGroupsAndPermissions = () => {};
        return category;
      },
      mobileView: true,
    });

    const rawData = {
      id: 1,
      topics_all_time: 100,
    };

    const result = CategoryList._buildCategoryResult(rawData, "all");

    assert.true(result.statTotal.includes("100"));

    Site.current = originalSiteCurrent;
  });

  test("list fetches and clears categories from PreloadStore", async function (assert) {
    const mockResult = {
      category_list: {
        categories: [{ id: 1, name: "Test", topics_all_time: 10 }],
        can_create_category: true,
        can_create_topic: true,
      },
    };
    // Store the mock result in PreloadStore under the correct key
    PreloadStore.store("categories_list", mockResult);

    // Spy on AJAX to ensure it is NOT called
    let ajaxCalled = false;
    pretender.get("/categories.json", () => {
      ajaxCalled = true;
      return response({});
    });

    const categoryList = await CategoryList.list(this.store);

    assert.true(categoryList instanceof CategoryList, "Returns a CategoryList");
    assert.true(categoryList.can_create_category, "can_create_category is set");
    assert.true(categoryList.can_create_topic, "can_create_topic is set");
    assert.false(
      ajaxCalled,
      "AJAX should not be called if PreloadStore is used"
    );
    assert.strictEqual(
      PreloadStore.get("categories_list"),
      undefined,
      "PreloadStore key is cleared after use"
    );
  });

  test("list includes parent category ID in request", async function (assert) {
    const parentCategory = { id: 5 };
    let requestData = {};

    pretender.get("/categories.json", (request) => {
      requestData = request.queryParams;
      return response({
        category_list: { categories: [] },
      });
    });

    await CategoryList.list(this.store, parentCategory);

    assert.strictEqual(parseInt(requestData.parent_category_id, 10), 5);
  });

  test(".create creates new CategoryList instance", function (assert) {
    const attrs = {
      categories: [],
      can_create_category: true,
    };

    const categoryList = CategoryList.create(attrs);

    assert.true(categoryList instanceof CategoryList);
  });

  test("loadMore loads more categories successfully", async function (assert) {
    let requestData = {};

    pretender.get("/categories.json", (request) => {
      requestData = request.queryParams;
      return response({
        category_list: {
          categories: [{ id: 2, name: "New Category", topics_all_time: 5 }],
        },
      });
    });

    const categoryList = CategoryList.create({
      categories: [],
      store: this.store,
      page: 1,
    });

    await categoryList.loadMore();

    assert.strictEqual(categoryList.page, 2);
    assert.false(categoryList.isLoading);
    assert.strictEqual(parseInt(requestData.page, 10), 2);
  });

  test("loadMore sets fetchedLastPage when no more categories", async function (assert) {
    pretender.get("/categories.json", () => {
      return response({
        category_list: { categories: [] },
      });
    });

    const categoryList = CategoryList.create({
      categories: [],
      store: this.store,
    });

    await categoryList.loadMore();

    assert.true(categoryList.fetchedLastPage);
  });

  test("loadMore includes parent category ID in request", async function (assert) {
    const parentCategory = { id: 3 };
    let requestData = {};

    pretender.get("/categories.json", (request) => {
      requestData = request.queryParams;
      return response({
        category_list: { categories: [] },
      });
    });

    const categoryList = CategoryList.create({
      categories: [],
      store: this.store,
      parentCategory,
    });

    await categoryList.loadMore();

    assert.strictEqual(parseInt(requestData.page, 10), 2);
    assert.strictEqual(parseInt(requestData.parent_category_id, 10), 3);
  });

  test("loadMore does not load when already loading", async function (assert) {
    let ajaxCalled = false;

    pretender.get("/categories.json", () => {
      ajaxCalled = true;
      return response({});
    });

    const categoryList = CategoryList.create({
      categories: [],
      store: this.store,
      isLoading: true,
    });

    await categoryList.loadMore();

    assert.false(ajaxCalled, "Ajax should not be called");
  });

  test("loadMore does not load when last page is fetched", async function (assert) {
    let ajaxCalled = false;

    pretender.get("/categories.json", () => {
      ajaxCalled = true;
      return response({});
    });

    const categoryList = CategoryList.create({
      categories: [],
      store: this.store,
      fetchedLastPage: true,
    });

    await categoryList.loadMore();

    assert.false(ajaxCalled, "Ajax should not be called");
  });

  test("loadMore handles ajax error gracefully", async function (assert) {
    pretender.get("/categories.json", () => {
      return response(500, { errors: ["Network error"] });
    });

    const categoryList = CategoryList.create({
      categories: [],
      store: this.store,
    });

    try {
      await categoryList.loadMore();
    } catch {
      // Error should be thrown but loading state should be reset
    }

    assert.false(categoryList.isLoading);
  });

  test("CategoryList behaves like an array", function (assert) {
    withSilencedDeprecations(
      "discourse.legacy-array-like-object.proxied-array",
      () => {
        const categories = [
          { id: 1, name: "Cat 1", topics_all_time: 10 },
          { id: 2, name: "Cat 2", topics_all_time: 20 },
          { id: 3, name: "Cat 3", topics_all_time: 30 },
        ];
        const list = CategoryList.create({ categories });

        // list[0] returns the first element
        assert.strictEqual(list[0].id, 1, "list[0] returns first category");

        // list.length returns correct length
        assert.strictEqual(
          list.length,
          3,
          "list.length returns correct length"
        );

        // forEach works
        let ids = [];
        list.forEach((cat) => ids.push(cat.id));
        assert.deepEqual(
          ids,
          [1, 2, 3],
          "forEach iterates over all categories"
        );

        // map works
        const names = list.map((cat) => cat.name);
        assert.deepEqual(
          names,
          ["Cat 1", "Cat 2", "Cat 3"],
          "map returns names"
        );

        // filter works
        const filtered = list.filter((cat) => cat.topics_all_time > 10);
        assert.strictEqual(filtered.length, 2, "filter returns correct number");
        assert.strictEqual(
          filtered[0].id,
          2,
          "filter returns correct category"
        );

        // find works
        const found = list.find((cat) => cat.id === 2);
        assert.strictEqual(
          found.name,
          "Cat 2",
          "find returns correct category"
        );

        // findIndex works
        const foundIdx = list.findIndex((cat) => cat.id === 3);
        assert.strictEqual(foundIdx, 2, "findIndex returns correct index");

        // some works
        assert.true(
          list.some((cat) => cat.topics_all_time === 20),
          "some returns true if any match"
        );

        // every works
        assert.true(
          list.every((cat) => cat.id > 0),
          "every returns true if all match"
        );
        assert.false(
          list.every((cat) => cat.topics_all_time > 10),
          "every returns false if not all match"
        );

        // reduce works
        const totalTopics = list.reduce(
          (sum, cat) => sum + cat.topics_all_time,
          0
        );
        assert.strictEqual(totalTopics, 60, "reduce sums topics_all_time");

        // slice works
        const sliced = list.slice(1);
        assert.strictEqual(sliced.length, 2, "slice returns correct length");
        assert.strictEqual(sliced[0].id, 2, "slice returns correct element");

        // concat works
        const extra = { id: 4, name: "Cat 4", topics_all_time: 40 };
        const combined = list.concat([extra]);
        assert.strictEqual(combined.length, 4, "concat returns correct length");
        assert.strictEqual(combined[3].id, 4, "concat returns correct element");

        // reverse works
        const reversed = list.slice().reverse();
        assert.deepEqual(
          reversed.map((cat) => cat.id),
          [3, 2, 1],
          "reverse returns reversed array"
        );

        // includes works
        assert.true(
          list.includes(list[1]),
          "includes returns true for contained element"
        );
        assert.false(
          list.includes({ id: 99 }),
          "includes returns false for non-contained element"
        );

        // at works
        assert.strictEqual(list.at(0).id, 1, "at(0) returns first element");
        assert.strictEqual(list.at(-1).id, 3, "at(-1) returns last element");
      }
    );
  });
});
