import EmberObject, { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Model | category", function (hooks) {
  setupTest(hooks);

  test("parentCategory and subcategories", function (assert) {
    const foo = Site.current().updateCategory({
      id: 12345,
      slug: "foo",
    });

    const bar = Site.current().updateCategory({
      id: 12346,
      slug: "bar",
      parent_category_id: 12345,
    });

    const baz = Site.current().updateCategory({
      id: 12347,
      slug: "baz",
      parent_category_id: 12345,
    });

    assert.deepEqual(foo.subcategories, [bar, baz]);
    assert.strictEqual(bar.parentCategory, foo);
    assert.strictEqual(baz.parentCategory, foo);
  });

  test("slugFor", function (assert) {
    const store = getOwner(this).lookup("service:store");

    const slugFor = function (cat, val, text) {
      assert.strictEqual(Category.slugFor(cat), val, text);
    };

    slugFor(
      store.createRecord("category", { slug: "hello" }),
      "hello",
      "It calculates the proper slug for hello"
    );
    slugFor(
      store.createRecord("category", { id: 123, slug: "" }),
      "123-category",
      "It returns id-category for empty strings"
    );
    slugFor(
      store.createRecord("category", { id: 456 }),
      "456-category",
      "It returns id-category for undefined slugs"
    );
    slugFor(
      store.createRecord("category", { slug: "熱帶風暴畫眉" }),
      "熱帶風暴畫眉",
      "It can be non english characters"
    );

    const parentCategory = Site.current().updateCategory({
      id: 345,
      slug: "darth",
    });
    slugFor(
      store.createRecord("category", {
        slug: "luke",
        parent_category_id: parentCategory.id,
      }),
      "darth/luke",
      "it uses the parent slug before the child"
    );

    slugFor(
      store.createRecord("category", {
        id: 555,
        parent_category_id: parentCategory.id,
      }),
      "darth/555-category",
      "it uses the parent slug before the child and then uses id"
    );

    parentCategory.set("slug", null);
    slugFor(
      store.createRecord("category", {
        id: 555,
        parent_category_id: parentCategory.id,
      }),
      "345-category/555-category",
      "it uses the parent before the child and uses ids for both"
    );
  });

  test("findBySlug", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const darth = store.createRecord("category", { id: 1, slug: "darth" }),
      luke = store.createRecord("category", {
        id: 2,
        slug: "luke",
        parentCategory: darth,
      }),
      hurricane = store.createRecord("category", {
        id: 3,
        slug: "熱帶風暴畫眉",
      }),
      newsFeed = store.createRecord("category", {
        id: 4,
        slug: "뉴스피드",
        parentCategory: hurricane,
      }),
      time = store.createRecord("category", {
        id: 5,
        slug: "时间",
        parentCategory: darth,
      }),
      bah = store.createRecord("category", {
        id: 6,
        slug: "bah",
        parentCategory: hurricane,
      }),
      categoryList = [darth, luke, hurricane, newsFeed, time, bah];

    sinon.stub(Category, "list").returns(categoryList);

    assert.deepEqual(
      Category.findBySlug("darth"),
      darth,
      "we can find a category"
    );
    assert.deepEqual(
      Category.findBySlug("luke", "darth"),
      luke,
      "we can find the other category with parent category"
    );
    assert.deepEqual(
      Category.findBySlug("熱帶風暴畫眉"),
      hurricane,
      "we can find a category with CJK slug"
    );
    assert.deepEqual(
      Category.findBySlug("뉴스피드", "熱帶風暴畫眉"),
      newsFeed,
      "we can find a category with CJK slug whose parent slug is also CJK"
    );
    assert.deepEqual(
      Category.findBySlug("时间", "darth"),
      time,
      "we can find a category with CJK slug whose parent slug is english"
    );
    assert.deepEqual(
      Category.findBySlug("bah", "熱帶風暴畫眉"),
      bah,
      "we can find a category with english slug whose parent slug is CJK"
    );
  });

  test("findSingleBySlug", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const darth = store.createRecord("category", { id: 1, slug: "darth" }),
      luke = store.createRecord("category", {
        id: 2,
        slug: "luke",
        parentCategory: darth,
      }),
      hurricane = store.createRecord("category", {
        id: 3,
        slug: "熱帶風暴畫眉",
      }),
      newsFeed = store.createRecord("category", {
        id: 4,
        slug: "뉴스피드",
        parentCategory: hurricane,
      }),
      time = store.createRecord("category", {
        id: 5,
        slug: "时间",
        parentCategory: darth,
      }),
      bah = store.createRecord("category", {
        id: 6,
        slug: "bah",
        parentCategory: hurricane,
      }),
      categoryList = [darth, luke, hurricane, newsFeed, time, bah];

    sinon.stub(Category, "list").returns(categoryList);

    assert.deepEqual(
      Category.findSingleBySlug("darth"),
      darth,
      "we can find a category"
    );
    assert.deepEqual(
      Category.findSingleBySlug("darth/luke"),
      luke,
      "we can find the other category with parent category"
    );
    assert.deepEqual(
      Category.findSingleBySlug("熱帶風暴畫眉"),
      hurricane,
      "we can find a category with CJK slug"
    );
    assert.deepEqual(
      Category.findSingleBySlug("熱帶風暴畫眉/뉴스피드"),
      newsFeed,
      "we can find a category with CJK slug whose parent slug is also CJK"
    );
    assert.deepEqual(
      Category.findSingleBySlug("darth/时间"),
      time,
      "we can find a category with CJK slug whose parent slug is english"
    );
    assert.deepEqual(
      Category.findSingleBySlug("熱帶風暴畫眉/bah"),
      bah,
      "we can find a category with english slug whose parent slug is CJK"
    );
  });

  test("findBySlugPathWithID", function (assert) {
    const store = getOwner(this).lookup("service:store");

    const foo = store.createRecord("category", { id: 1, slug: "foo" });
    const bar = store.createRecord("category", {
      id: 2,
      slug: "bar",
      parentCategory: foo,
    });
    const baz = store.createRecord("category", {
      id: 3,
      slug: "baz",
      parentCategory: foo,
    });

    const categoryList = [foo, bar, baz];
    sinon.stub(Category, "list").returns(categoryList);

    assert.deepEqual(Category.findBySlugPathWithID("foo"), foo);
    assert.deepEqual(Category.findBySlugPathWithID("foo/bar"), bar);
    assert.deepEqual(Category.findBySlugPathWithID("foo/bar/"), bar);
    assert.deepEqual(Category.findBySlugPathWithID("foo/baz/3"), baz);
  });

  test("minimumRequiredTags", function (assert) {
    const store = getOwner(this).lookup("service:store");

    const foo = store.createRecord("category", {
      id: 1,
      slug: "foo",
      required_tag_groups: [{ name: "bar", min_count: 2 }],
    });

    assert.strictEqual(foo.minimumRequiredTags, 2);

    const bar = store.createRecord("category", {
      id: 2,
      slug: "bar",
    });

    assert.strictEqual(bar.minimumRequiredTags, null);

    const baz = store.createRecord("category", {
      id: 3,
      slug: "baz",
      minimum_required_tags: 0,
    });

    assert.strictEqual(baz.minimumRequiredTags, null);

    const qux = store.createRecord("category", {
      id: 4,
      slug: "qux",
      minimum_required_tags: 2,
    });

    assert.strictEqual(qux.minimumRequiredTags, 2);

    const quux = store.createRecord("category", {
      id: 5,
      slug: "quux",
      required_tag_groups: [],
    });

    assert.strictEqual(quux.minimumRequiredTags, null);

    const foobar = store.createRecord("category", {
      id: 1,
      slug: "foo",
      minimum_required_tags: 2,
      required_tag_groups: [{ name: "bar", min_count: 1 }],
    });

    assert.strictEqual(foobar.minimumRequiredTags, 2);

    const barfoo = store.createRecord("category", {
      id: 1,
      slug: "foo",
      minimum_required_tags: 2,
      required_tag_groups: [
        { name: "foo", min_count: 1 },
        { name: "bar", min_count: 2 },
      ],
    });

    assert.strictEqual(barfoo.minimumRequiredTags, 3);
  });

  test("search with category name", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category1 = store.createRecord("category", {
      id: 1,
      name: "middle term",
      slug: "different-slug",
    });
    const category2 = store.createRecord("category", {
      id: 2,
      name: "middle term",
      slug: "another-different-slug",
    });
    const subcategory = store.createRecord("category", {
      id: 3,
      name: "middle term",
      slug: "another-different-slug2",
      parent_category_id: 2,
    });

    sinon
      .stub(Category, "listByActivity")
      .returns([category1, category2, subcategory]);

    assert.deepEqual(
      Category.search("term", { limit: 0 }),
      [],
      "returns an empty array when limit is 0"
    );
    assert.deepEqual(
      Category.search(""),
      [category1, category2],
      "orders by activity if no term is matched"
    );
    assert.deepEqual(
      Category.search("term"),
      [category1, category2, subcategory],
      "orders by activity"
    );

    category2.set("name", "TeRm start");
    assert.deepEqual(
      Category.search("tErM"),
      [category2, category1, subcategory],
      "ignores case of category name and search term"
    );

    category2.set("name", "term start");
    assert.deepEqual(
      Category.search("term"),
      [category2, category1, subcategory],
      "orders matching begin with and then contains"
    );

    assert.deepEqual(
      Category.search("term", { parentCategoryId: 2 }),
      [subcategory],
      "search only subcategories belonging to specific parent category"
    );

    sinon.restore();

    const child_category1 = store.createRecord("category", {
        id: 3,
        name: "term start",
        parent_category_id: category1.id,
      }),
      read_restricted_category = store.createRecord("category", {
        id: 4,
        name: "some term",
        read_restricted: true,
      });

    sinon
      .stub(Category, "listByActivity")
      .returns([
        read_restricted_category,
        category1,
        child_category1,
        category2,
      ]);

    assert.deepEqual(
      Category.search(""),
      [category1, category2, read_restricted_category],
      "prioritize non read_restricted and does not include child categories when term is blank"
    );

    assert.deepEqual(
      Category.search("", { limit: 3 }),
      [category1, category2, read_restricted_category],
      "prioritize non read_restricted and does not include child categories categories when term is blank with limit"
    );

    assert.deepEqual(
      Category.search("term"),
      [child_category1, category2, category1, read_restricted_category],
      "prioritize non read_restricted"
    );

    assert.deepEqual(
      Category.search("term", { limit: 3 }),
      [child_category1, category2, read_restricted_category],
      "prioritize non read_restricted with limit"
    );
  });

  test("search with accented category name", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category1 = store.createRecord("category", {
      id: 1,
      name: "Éditions",
      slug: "publications",
    });
    const category2 = store.createRecord("category", {
      id: 2,
      name: "Cinéma",
      slug: "films",
    });

    sinon.stub(Category, "listByActivity").returns([category1, category2]);

    assert.deepEqual(
      Category.search("editions"),
      [category1],
      "finds accented category with unaccented search term"
    );
    assert.deepEqual(
      Category.search("cinema"),
      [category2],
      "finds accented category by unaccented name"
    );
    assert.deepEqual(
      Category.search("Édit"),
      [category1],
      "finds accented category with accented search term"
    );
  });

  test("search with category slug", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const category1 = store.createRecord("category", {
      id: 1,
      name: "middle term",
      slug: "different-slug",
    });
    const category2 = store.createRecord("category", {
      id: 2,
      name: "middle term",
      slug: "another-different-slug",
    });

    sinon.stub(Category, "listByActivity").returns([category1, category2]);

    assert.deepEqual(
      Category.search("different-slug"),
      [category1, category2],
      "returns the right categories"
    );
    assert.deepEqual(
      Category.search("another-different"),
      [category2],
      "returns the right categories"
    );

    category2.set("slug", "ANOTher-DIFfereNT");
    assert.deepEqual(
      Category.search("anOtHer-dIfFeREnt"),
      [category2],
      "ignores case of category slug and search term"
    );
  });

  test("sortCategories returns categories with child categories sorted after parent categories", function (assert) {
    const categories = [
      { id: 1003, name: "Test Sub Sub", parent_category_id: 1002 },
      { id: 1001, name: "Test" },
      { id: 1004, name: "Test Sub Sub Sub", parent_category_id: 1003 },
      { id: 1002, name: "Test Sub", parent_category_id: 1001 },
      { id: 1005, name: "Test Sub Sub Sub2", parent_category_id: 1003 },
      { id: 1006, name: "Test2" },
      { id: 1000, name: "Test2 Sub", parent_category_id: 1006 },
      { id: 997, name: "Test2 Sub Sub2", parent_category_id: 1000 },
      { id: 999, name: "Test2 Sub Sub", parent_category_id: 1000 },
    ];

    assert.deepEqual(
      Category.sortCategories(categories).map((item) => item.name),
      [
        "Test",
        "Test Sub",
        "Test Sub Sub",
        "Test Sub Sub Sub",
        "Test Sub Sub Sub2",
        "Test2",
        "Test2 Sub",
        "Test2 Sub Sub2",
        "Test2 Sub Sub",
      ]
    );
  });

  test("asyncFindByIds - do not request categories that have been loaded already", async function (assert) {
    const stub = sinon.stub(console, "warn");
    const requestedIds = [];
    pretender.get("/categories/find", (request) => {
      const ids = request.queryParams.ids.map((id) => parseInt(id, 10));
      requestedIds.push(ids);
      return response({
        categories: ids.map((id) => ({ id, slug: `category-${id}` })),
      });
    });

    const site = this.owner.lookup("service:site");
    site.set("lazy_load_categories", true);

    await Category.asyncFindByIds([12345, 12346]);
    assert.deepEqual(requestedIds, [[12345, 12346]]);

    await Category.asyncFindByIds([12345, 12346, 12347]);
    assert.deepEqual(requestedIds, [[12345, 12346], [12347]]);
    assert.true(
      stub.calledWith(
        "WARNING: Multiple calls to Category.asyncFindByIds within a second. Could they be combined?"
      )
    );

    await Category.asyncFindByIds([12345]);
    assert.deepEqual(requestedIds, [[12345, 12346], [12347]]);

    stub.restore();
  });

  test("asyncFindByIds preserves request order and skips missing categories", async function (assert) {
    const missingId = 12345;
    const categoryIds = [12346, 12347];
    const site = this.owner.lookup("service:site");
    site.set("lazy_load_categories", true);
    site.updateCategory({ id: missingId, name: "Stale category" });
    pretender.get("/categories/find", () =>
      response({
        categories: categoryIds.map((id) => ({ id, name: `Category ${id}` })),
      })
    );

    const ids = [missingId, ...categoryIds.toReversed()];
    const categories = await Category.asyncFindByIds(ids);
    assert.deepEqual(
      categories.map((category) => category.id),
      categoryIds.toReversed(),
      "available categories keep their requested order"
    );
    assert.deepEqual(
      (await Category.asyncFindByIds(ids)).map((category) => category.id),
      categoryIds.toReversed(),
      "cached results match"
    );
  });

  test("asyncFindByIds caches entirely missing categories", async function (assert) {
    const notFoundStatus = 404;
    const missingId = 12345;
    this.owner.lookup("service:site").set("lazy_load_categories", true);
    const request = sinon.spy(() => response(notFoundStatus, {}));
    pretender.get("/categories/find", request);

    assert.deepEqual(
      await Category.asyncFindByIds([missingId]),
      [],
      "missing categories are omitted"
    );
    assert.strictEqual(
      await Category.asyncFindById(missingId),
      undefined,
      "single lookup returns undefined"
    );
    assert.true(request.calledOnce, "missing IDs are cached");
  });

  test("asyncFindByIds propagates server errors", async function (assert) {
    const serverErrorStatus = 500;
    this.owner.lookup("service:site").set("lazy_load_categories", true);
    pretender.get("/categories/find", () => response(serverErrorStatus, {}));

    await assert.rejects(
      Category.asyncFindByIds([12345]),
      "server errors are not treated as missing categories"
    );
  });

  test("registerCategorySaveProperty includes property in save request", async function (assert) {
    const done = assert.async();

    withPluginApi((api) => {
      api.registerCategorySaveProperty("cats_and_dogs");
    });

    const category = Category.create({
      id: 12345,
      name: "Test Category",
      cats_and_dogs: 42,
      group_permissions: [{ permission_type: 1, group_name: "everyone" }],
      permissions: ["everyone"],
    });

    pretender.put("/categories/12345", (request) => {
      const requestBody = JSON.parse(request.requestBody);
      assert.strictEqual(
        requestBody.cats_and_dogs,
        42,
        "registered property is included in category save request"
      );
      done();
      return response(200, {
        category: {
          id: 12345,
          name: "Test Category",
          cats_and_dogs: 42,
        },
      });
    });

    await category.save();
  });
});

module("Unit | Model | category | site lookups", function (hooks) {
  setupTest(hooks);

  test("cached lookups resolve parents after several appends", function (assert) {
    const site = Site.current();
    const parent = site.updateCategory({ id: 8675301, slug: "parent" });
    const child = site.updateCategory({
      id: 8675302,
      slug: "child",
      parent_category_id: parent.id,
    });
    const sibling = site.updateCategory({
      id: 8675303,
      slug: "sibling",
      parent_category_id: parent.id,
    });

    assert.deepEqual(
      parent.subcategories,
      [child, sibling],
      "the collection includes both children"
    );
    assert.strictEqual(
      Category.findById(parent.id),
      parent,
      "direct lookup finds the appended parent"
    );
    assert.strictEqual(
      child.parentCategory,
      parent,
      "the first child resolves its parent"
    );
    assert.strictEqual(
      sibling.parentCategory,
      parent,
      "the second child resolves its parent"
    );
  });

  test("id map stays cached across record updates and invalidates classic consumers", function (assert) {
    const store = this.owner.lookup("service:store");
    const site = store.createRecord("site", {
      categories: [{ id: 1, name: "One" }],
    });
    class Consumer extends EmberObject {
      @computed("site.categoriesById.[]")
      get category() {
        return this.site.categoriesById.get(1);
      }
    }
    const consumer = Consumer.create({ site });
    const first = site.categoriesById;
    const existing = consumer.category;

    site.updateCategory({ id: 1, name: "Renamed" });

    assert.strictEqual(
      site.categoriesById,
      first,
      "field updates reuse the map"
    );
    assert.strictEqual(
      first.get(1).name,
      "Renamed",
      "the map holds live records"
    );

    site.removeCategory(1);

    const removed = site.categoriesById;
    assert.notStrictEqual(removed, first, "removal invalidates the map");
    assert.false(removed.has(1), "the removed category is absent");
    assert.strictEqual(
      consumer.category,
      undefined,
      "classic consumers see removal"
    );
    assert.strictEqual(
      site.categoriesById,
      removed,
      "reads reuse the rebuilt map"
    );

    site.categories = [existing];

    assert.notStrictEqual(
      site.categoriesById,
      removed,
      "replacement invalidates the map"
    );
    assert.strictEqual(
      consumer.category,
      existing,
      "classic consumers see replacement"
    );
    consumer.destroy();
  });

  test("bulk merge appends once and reuses duplicate ids in page order", function (assert) {
    const site = this.owner.lookup("service:store").createRecord("site", {
      categories: [{ id: 1, name: "One" }],
    });
    const existing = site.categories[0];
    const loadedIds = new Set([99]);
    site.set("loadedCategoryIds", loadedIds);
    const push = sinon.spy(site.categories, "push");
    const result = site.updateCategories([
      { id: 2, name: "Two" },
      { id: 1, name: "Renamed" },
      { id: 3, name: "Three" },
      { id: 2, name: "Two renamed" },
    ]);

    assert.deepEqual(
      result.map((category) => category.id),
      [2, 1, 3, 2],
      "page order is preserved"
    );
    assert.strictEqual(result[1], existing, "existing records retain identity");
    assert.strictEqual(
      result[0],
      result[3],
      "duplicate ids reuse the new record"
    );
    assert.strictEqual(
      result[0].name,
      "Two renamed",
      "later data wins for duplicate ids"
    );
    assert.deepEqual(
      site.categories.map((category) => category.id),
      [1, 2, 3],
      "each new id is appended once"
    );
    assert.true(push.calledOnce, "the page uses a single append");
    assert.deepEqual(
      push.firstCall.args,
      [result[0], result[2]],
      "the append contains only new records"
    );
    assert.strictEqual(
      site.loadedCategoryIds,
      loadedIds,
      "the existing loaded set is preserved"
    );
    assert.deepEqual(
      [...loadedIds],
      [99, 2, 1, 3],
      "all merged ids are recorded without losing earlier ids"
    );
  });

  test("bulk merge preserves omitted metadata and refreshes category types", function (assert) {
    const site = this.owner.lookup("service:store").createRecord("site", {
      categories: [
        {
          id: 123451,
          name: "One",
          permission: 1,
          has_children: true,
          category_types: { old: true },
        },
      ],
    });
    const pojos = [
      {
        id: 123451,
        permission: null,
        has_children: null,
        category_types: { updated: true },
      },
      {
        id: 123452,
        name: "Two",
        permission: null,
        has_children: undefined,
        category_types: { created: true },
      },
    ];

    const [existing, created] = site.updateCategories(pojos);

    assert.strictEqual(
      existing.permission,
      1,
      "null permission preserves the existing value"
    );
    assert.true(
      existing.has_children,
      "null children metadata preserves the existing value"
    );
    assert.true(
      existing.categoryTypes.updated,
      "existing category types are refreshed"
    );
    assert.true(created instanceof Category, "new rows are category records");
    assert.true(
      created.categoryTypes.created,
      "new category types are initialized"
    );
    for (const pojo of pojos) {
      assert.false(
        Object.hasOwn(pojo, "permission"),
        "null permission is deleted from the input"
      );
      assert.false(
        Object.hasOwn(pojo, "has_children"),
        "missing children metadata is deleted from the input"
      );
    }

    site.updateCategories([{ id: 123451, permission: 0, has_children: false }]);

    assert.strictEqual(
      existing.permission,
      0,
      "non-null falsy permission is applied"
    );
    assert.false(
      existing.has_children,
      "explicit false children metadata is applied"
    );
  });

  test("bulk merge with no new records leaves the category collection intact", function (assert) {
    const site = this.owner.lookup("service:store").createRecord("site", {
      categories: [{ id: 1, name: "One" }],
    });
    const first = site.categoriesById;
    const push = sinon.spy(site.categories, "push");

    assert.deepEqual(
      site.updateCategories([]),
      [],
      "an empty page returns no records"
    );
    assert.true(
      site.loadedCategoryIds instanceof Set,
      "an empty first page initializes loaded ids"
    );
    const [record] = site.updateCategories([{ id: 1, name: "Renamed" }]);

    assert.strictEqual(
      record,
      first.get(1),
      "existing-only pages retain identity"
    );
    assert.false(push.called, "empty and existing-only pages do not append");
    assert.strictEqual(
      site.categoriesById,
      first,
      "existing-only pages reuse the id map"
    );
    assert.deepEqual(
      [...site.loadedCategoryIds],
      [1],
      "existing ids are also recorded as loaded"
    );
  });
});

module(
  "Unit | Model | category | async search and descendants",
  function (hooks) {
    setupTest(hooks);

    test("asyncSearch asks for postable categories only when told", async function (assert) {
      const sent = [];
      pretender.post("/categories/search", (request) => {
        sent.push(
          new URLSearchParams(request.requestBody).get("only_postable")
        );
        return response({ categories: [], categories_count: 0 });
      });

      await Category.asyncSearch("postable-a", { onlyPostable: true });
      await Category.asyncSearch("postable-b");

      assert.strictEqual(sent[0], "true", "the rule is sent");
      assert.notStrictEqual(sent[1], "true", "it is absent otherwise");
    });

    test("clearAsyncSearchCache makes the next search ask the server again", async function (assert) {
      let requests = 0;
      pretender.post("/categories/search", () => {
        requests++;
        return response({ categories: [], categories_count: 0 });
      });

      await Category.asyncSearch("cached-term");
      await Category.asyncSearch("cached-term");
      assert.strictEqual(requests, 1, "a repeated search is cached");

      Category.clearAsyncSearchCache();
      await Category.asyncSearch("cached-term");
      assert.strictEqual(requests, 2, "the cleared search is fetched again");
    });

    test("asyncFindDescendants returns the preloaded tree without asking the server", async function (assert) {
      const site = Site.current();
      site.set("lazy_load_categories", false);
      site.updateCategories([
        { id: 9800, name: "Root", slug: "root9800" },
        {
          id: 9801,
          name: "Child",
          slug: "child9801",
          parent_category_id: 9800,
        },
        {
          id: 9802,
          name: "Grandchild",
          slug: "grandchild9802",
          parent_category_id: 9801,
        },
      ]);
      let requests = 0;
      pretender.post("/categories/search", () => {
        requests++;
        return response({ categories: [], categories_count: 0 });
      });

      const result = await Category.asyncFindDescendants(
        Category.findById(9800)
      );

      assert.deepEqual(
        result.map((category) => category.id),
        [9800, 9801, 9802]
      );
      assert.strictEqual(requests, 0, "nothing is fetched");
    });

    test("asyncFindDescendants pages every level from the server when lazy", async function (assert) {
      const site = Site.current();
      site.set("lazy_load_categories", true);
      site.updateCategories([{ id: 9600, name: "Root", has_children: true }]);
      const children = Array.from({ length: 26 }, (_, index) => ({
        id: 9601 + index,
        name: `Child ${index}`,
        parent_category_id: 9600,
        has_children: index === 0 || index === 25,
      }));
      const levels = {
        9600: children,
        9601: [
          {
            id: 9700,
            name: "First grandchild",
            parent_category_id: 9601,
            has_children: true,
          },
        ],
        9626: [
          {
            id: 9701,
            name: "Last grandchild",
            parent_category_id: 9626,
            has_children: false,
          },
        ],
        9700: [
          {
            id: 9702,
            name: "Great grandchild",
            parent_category_id: 9700,
            has_children: false,
          },
        ],
      };
      const requests = [];
      pretender.post("/categories/search", (request) => {
        const params = new URLSearchParams(request.requestBody);
        const parent = Number(params.get("parent_category_id"));
        const page = Number(params.get("page") || 1);
        requests.push([parent, page]);
        const rows = levels[parent] ?? [];
        return response({
          categories_count: rows.length,
          categories: rows.slice((page - 1) * 25, page * 25),
          ancestors: [],
        });
      });

      const result = await Category.asyncFindDescendants(
        Category.findById(9600)
      );

      assert.deepEqual(
        result.map((category) => category.id),
        [9600, ...children.map((category) => category.id), 9700, 9701, 9702],
        "all pages and depths appear in breadth first order"
      );
      assert.deepEqual(
        [...new Set(requests.map(([parent]) => parent))].sort(),
        [9600, 9601, 9626, 9700],
        "only parents with children are searched"
      );
      assert.deepEqual(
        requests.filter(([parent]) => parent === 9600).map(([, page]) => page),
        [1, 2],
        "a level larger than one response is paged"
      );
    });
  }
);
