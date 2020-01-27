import createStore from "helpers/create-store";
import Category from "discourse/models/category";

QUnit.module("model:category");

QUnit.test("slugFor", assert => {
  const store = createStore();

  const slugFor = function(cat, val, text) {
    assert.equal(Category.slugFor(cat), val, text);
  };

  slugFor(
    store.createRecord("category", { slug: "hello" }),
    "hello",
    "It calculates the proper slug for hello"
  );
  slugFor(
    store.createRecord("category", { id: 123, slug: "" }),
    "-",
    "It returns - for empty slugs"
  );
  slugFor(
    store.createRecord("category", { id: 456 }),
    "-",
    "It returns - for undefined slugs"
  );
  slugFor(
    store.createRecord("category", { slug: "熱帶風暴畫眉" }),
    "熱帶風暴畫眉",
    "It can be non english characters"
  );

  const parentCategory = store.createRecord("category", {
    id: 345,
    slug: "darth"
  });
  slugFor(
    store.createRecord("category", {
      slug: "luke",
      parentCategory: parentCategory
    }),
    "darth/luke",
    "it uses the parent slug before the child"
  );

  slugFor(
    store.createRecord("category", { id: 555, parentCategory: parentCategory }),
    "darth/-",
    "it uses the parent slug before the child and then uses id"
  );

  parentCategory.set("slug", null);
  slugFor(
    store.createRecord("category", { id: 555, parentCategory: parentCategory }),
    "-/-",
    "it uses the parent before the child and uses ids for both"
  );
});

QUnit.test("findBySlug", assert => {
  assert.expect(6);

  const store = createStore();
  const darth = store.createRecord("category", { id: 1, slug: "darth" }),
    luke = store.createRecord("category", {
      id: 2,
      slug: "luke",
      parentCategory: darth
    }),
    hurricane = store.createRecord("category", { id: 3, slug: "熱帶風暴畫眉" }),
    newsFeed = store.createRecord("category", {
      id: 4,
      slug: "뉴스피드",
      parentCategory: hurricane
    }),
    time = store.createRecord("category", {
      id: 5,
      slug: "时间",
      parentCategory: darth
    }),
    bah = store.createRecord("category", {
      id: 6,
      slug: "bah",
      parentCategory: hurricane
    }),
    categoryList = [darth, luke, hurricane, newsFeed, time, bah];

  sandbox.stub(Category, "list").returns(categoryList);

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

  sandbox.restore();
});

QUnit.test("findSingleBySlug", assert => {
  assert.expect(6);

  const store = createStore();
  const darth = store.createRecord("category", { id: 1, slug: "darth" }),
    luke = store.createRecord("category", {
      id: 2,
      slug: "luke",
      parentCategory: darth
    }),
    hurricane = store.createRecord("category", { id: 3, slug: "熱帶風暴畫眉" }),
    newsFeed = store.createRecord("category", {
      id: 4,
      slug: "뉴스피드",
      parentCategory: hurricane
    }),
    time = store.createRecord("category", {
      id: 5,
      slug: "时间",
      parentCategory: darth
    }),
    bah = store.createRecord("category", {
      id: 6,
      slug: "bah",
      parentCategory: hurricane
    }),
    categoryList = [darth, luke, hurricane, newsFeed, time, bah];

  sandbox.stub(Category, "list").returns(categoryList);

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

QUnit.test("findBySlugPathWithID", assert => {
  const store = createStore();

  const foo = store.createRecord("category", { id: 1, slug: "foo" });
  const bar = store.createRecord("category", {
    id: 2,
    slug: "bar",
    parentCategory: foo
  });
  const baz = store.createRecord("category", {
    id: 3,
    slug: "baz",
    parentCategory: foo
  });

  const categoryList = [foo, bar, baz];
  sandbox.stub(Category, "list").returns(categoryList);

  assert.deepEqual(Category.findBySlugPathWithID("foo"), foo);
  assert.deepEqual(Category.findBySlugPathWithID("foo/bar"), bar);
  assert.deepEqual(Category.findBySlugPathWithID("foo/bar/"), bar);
  assert.deepEqual(Category.findBySlugPathWithID("foo/baz/3"), baz);
});

QUnit.test("search with category name", assert => {
  const store = createStore(),
    category1 = store.createRecord("category", {
      id: 1,
      name: "middle term",
      slug: "different-slug"
    }),
    category2 = store.createRecord("category", {
      id: 2,
      name: "middle term",
      slug: "another-different-slug"
    });

  sandbox.stub(Category, "listByActivity").returns([category1, category2]);

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
    [category1, category2],
    "orders by activity"
  );

  category2.set("name", "TeRm start");
  assert.deepEqual(
    Category.search("tErM"),
    [category2, category1],
    "ignores case of category name and search term"
  );

  category2.set("name", "term start");
  assert.deepEqual(
    Category.search("term"),
    [category2, category1],
    "orders matching begin with and then contains"
  );

  sandbox.restore();

  const child_category1 = store.createRecord("category", {
      id: 3,
      name: "term start",
      parent_category_id: category1.get("id")
    }),
    read_restricted_category = store.createRecord("category", {
      id: 4,
      name: "some term",
      read_restricted: true
    });

  sandbox
    .stub(Category, "listByActivity")
    .returns([read_restricted_category, category1, child_category1, category2]);

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

  sandbox.restore();
});

QUnit.test("search with category slug", assert => {
  const store = createStore(),
    category1 = store.createRecord("category", {
      id: 1,
      name: "middle term",
      slug: "different-slug"
    }),
    category2 = store.createRecord("category", {
      id: 2,
      name: "middle term",
      slug: "another-different-slug"
    });

  sandbox.stub(Category, "listByActivity").returns([category1, category2]);

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
