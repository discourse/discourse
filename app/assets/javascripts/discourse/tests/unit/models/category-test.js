import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
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

    assert.deepEqual(Category.sortCategories(categories).mapBy("name"), [
      "Test",
      "Test Sub",
      "Test Sub Sub",
      "Test Sub Sub Sub",
      "Test Sub Sub Sub2",
      "Test2",
      "Test2 Sub",
      "Test2 Sub Sub2",
      "Test2 Sub Sub",
    ]);
  });

  test("asyncFindByIds - do not request categories that have been loaded already", async function (assert) {
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

    await Category.asyncFindByIds([12345]);
    assert.deepEqual(requestedIds, [[12345, 12346], [12347]]);
  });
});
