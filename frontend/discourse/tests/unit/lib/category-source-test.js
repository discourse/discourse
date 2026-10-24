import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  fetchCategoryPage,
  loadDescendants,
  resolveCategories,
} from "discourse/lib/category-source";
import Site from "discourse/models/site";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function bodyParams(request) {
  return new URLSearchParams(request.requestBody);
}

module("Unit | lib | category-source", function (hooks) {
  setupTest(hooks);

  test("fetchCategoryPage sends the query and merges the page into the site", async function (assert) {
    let params;
    pretender.post("/categories/search", (request) => {
      params = bodyParams(request);
      return response({
        categories_count: 31,
        categories: [{ id: 9001, name: "Paged", slug: "paged" }],
        ancestors: [{ id: 9000, name: "Root", slug: "root" }],
      });
    });

    const page = await fetchCategoryPage({
      term: "pag",
      page: 2,
      parentCategoryId: 9000,
      rejectIds: [3, 4],
      includeUncategorized: false,
      includeSubcategories: false,
      prioritizedId: 7,
      onlyPostable: true,
    });

    assert.strictEqual(params.get("term"), "pag");
    assert.strictEqual(params.get("page"), "2");
    assert.strictEqual(params.get("parent_category_id"), "9000");
    assert.deepEqual(params.getAll("reject_category_ids[]"), ["3", "4"]);
    assert.strictEqual(params.get("include_uncategorized"), "false");
    assert.strictEqual(params.get("include_subcategories"), "false");
    assert.strictEqual(params.get("prioritized_category_id"), "7");
    assert.strictEqual(params.get("only_postable"), "true");
    assert.strictEqual(
      params.get("include_ancestors"),
      "true",
      "ancestors always come along so badges can show parents"
    );

    assert.strictEqual(page.total, 31, "the server count");
    assert.deepEqual(
      page.categories.map((category) => category.id),
      [9001]
    );
    assert.deepEqual(
      page.ancestors.map((category) => category.id),
      [9000]
    );
    assert.strictEqual(
      Site.current().categoriesById.get(9001),
      page.categories[0],
      "the page's categories are the site's records"
    );
    assert.strictEqual(
      Site.current().categoriesById.get(9000)?.name,
      "Root",
      "ancestors are merged too"
    );
  });

  test("fetchCategoryPage leaves out options it was not given", async function (assert) {
    let params;
    pretender.post("/categories/search", (request) => {
      params = bodyParams(request);
      return response({ categories_count: 0, categories: [], ancestors: [] });
    });

    await fetchCategoryPage({ term: "" });

    for (const name of [
      "parent_category_id",
      "reject_category_ids[]",
      "include_uncategorized",
      "include_subcategories",
      "prioritized_category_id",
      "only_postable",
    ]) {
      assert.false(
        params.has(name),
        `${name} falls back to the server default`
      );
    }
  });

  test("fetchCategoryPage rejects an aborted request without merging it", async function (assert) {
    pretender.post("/categories/search", () =>
      response({
        categories_count: 1,
        categories: [{ id: 9050, name: "Stale", slug: "stale" }],
        ancestors: [],
      })
    );
    const controller = new AbortController();
    controller.abort();

    await assert.rejects(
      fetchCategoryPage({ term: "x", signal: controller.signal }),
      "an aborted request does not resolve"
    );
    assert.strictEqual(
      Site.current().categoriesById.get(9050),
      undefined,
      "the stale page never reaches the site"
    );
  });

  test("resolveCategories returns known categories in the requested order", async function (assert) {
    const site = Site.current();
    const [first, second] = site.categories;

    const result = await resolveCategories([
      second.id,
      999999,
      String(first.id),
    ]);

    assert.deepEqual(
      result.map((category) => category.id),
      [second.id, first.id],
      "unknown ids are dropped, numeric strings resolve, and the order is kept"
    );
  });

  test("resolveCategories fetches ids the site has not loaded when lazy", async function (assert) {
    const site = Site.current();
    site.set("lazy_load_categories", true);
    let requested;
    pretender.get("/categories/find", (request) => {
      requested = request.queryParams.ids;
      return response({
        categories: [{ id: 9301, name: "Fetched", slug: "fetched" }],
      });
    });

    const result = await resolveCategories([9301]);

    assert.deepEqual(requested, ["9301"], "the missing id is requested");
    assert.deepEqual(
      result.map((category) => category.id),
      [9301]
    );
    assert.strictEqual(
      site.categoriesById.get(9301),
      result[0],
      "the fetched category is the site's record"
    );
  });

  test("loadDescendants walks the local tree", async function (assert) {
    const site = Site.current();
    site.updateCategories([
      { id: 9100, name: "Root", slug: "root" },
      { id: 9101, name: "Child", slug: "child", parent_category_id: 9100 },
      {
        id: 9102,
        name: "Grandchild",
        slug: "grandchild",
        parent_category_id: 9101,
      },
      { id: 9103, name: "Other", slug: "other" },
    ]);
    pretender.post("/categories/search", () => {
      assert.true(false, "no request is made when categories are preloaded");
      return response({ categories_count: 0, categories: [] });
    });

    const result = await loadDescendants(site.categoriesById.get(9100));

    assert.deepEqual(
      result.map((category) => category.id),
      [9100, 9101, 9102],
      "the category comes first, then every level below it"
    );
  });

  test("loadDescendants fetches every level from the server when lazy", async function (assert) {
    const site = Site.current();
    site.set("lazy_load_categories", true);
    site.updateCategories([
      { id: 9200, name: "Root", slug: "root9200", has_children: true },
    ]);
    const children = {
      9200: [
        {
          id: 9201,
          name: "A",
          slug: "a9201",
          parent_category_id: 9200,
          has_children: true,
        },
        {
          id: 9202,
          name: "B",
          slug: "b9202",
          parent_category_id: 9200,
          has_children: false,
        },
      ],
      9201: [
        {
          id: 9203,
          name: "C",
          slug: "c9203",
          parent_category_id: 9201,
          has_children: false,
        },
      ],
    };
    pretender.post("/categories/search", (request) => {
      const params = bodyParams(request);
      const parent = Number(params.get("parent_category_id"));
      const page = Number(params.get("page") || 1);
      const rows = page === 1 ? (children[parent] ?? []) : [];
      return response({
        categories_count: (children[parent] ?? []).length,
        categories: rows,
        ancestors: [],
      });
    });

    const result = await loadDescendants(site.categoriesById.get(9200));

    assert.deepEqual(
      result.map((category) => category.id).sort(),
      [9200, 9201, 9202, 9203],
      "grandchildren are included"
    );
  });

  test("loadDescendants pages a level with more children than one response holds", async function (assert) {
    const site = Site.current();
    site.set("lazy_load_categories", true);
    site.updateCategories([
      { id: 9400, name: "Root", slug: "root9400", has_children: true },
    ]);
    const rows = Array.from({ length: 30 }, (_, index) => ({
      id: 9401 + index,
      name: `Child ${index}`,
      slug: `child-${9401 + index}`,
      parent_category_id: 9400,
      has_children: false,
    }));
    pretender.post("/categories/search", (request) => {
      const params = bodyParams(request);
      const parent = Number(params.get("parent_category_id"));
      const page = Number(params.get("page") || 1);
      const level = parent === 9400 ? rows : [];
      return response({
        categories_count: level.length,
        categories: level.slice((page - 1) * 25, page * 25),
        ancestors: [],
      });
    });

    const result = await loadDescendants(site.categoriesById.get(9400));

    assert.strictEqual(result.length, 31, "the root and all 30 children");
  });

  test("aborting in flight rejects before the response and never merges late rows", async function (assert) {
    const site = Site.current();
    let request;
    let requestStarted;
    const started = new Promise((resolve) => {
      requestStarted = resolve;
    });
    pretender.post(
      "/categories/search",
      (incoming) => {
        request = incoming;
        requestStarted();
        return response({
          categories_count: 1,
          categories: [
            { id: 9501, name: "Late child", parent_category_id: 9500 },
          ],
          ancestors: [{ id: 9500, name: "Late parent" }],
        });
      },
      true
    );
    const controller = new AbortController();
    const pending = fetchCategoryPage({
      term: "late",
      signal: controller.signal,
    });
    await started;
    controller.abort();
    await assert.rejects(
      pending,
      (error) => error.name === "AbortError",
      "abort settles without a response"
    );

    assert.true(!!request, "the request was already in flight");
    pretender.resolve(request);
    await settled();
    assert.strictEqual(
      site.categoriesById.get(9501),
      undefined,
      "the child was not merged"
    );
    assert.strictEqual(
      site.categoriesById.get(9500),
      undefined,
      "the ancestor was not merged"
    );
  });

  test("a page updates existing records and tolerates absent ancestors", async function (assert) {
    const site = Site.current();
    const category = site.categories[0];
    pretender.post("/categories/search", () =>
      response({
        categories_count: 1,
        categories: [{ id: category.id, name: "Updated category" }],
      })
    );

    const page = await fetchCategoryPage({ term: "updated" });

    assert.strictEqual(
      page.categories[0],
      category,
      "existing record identity is kept"
    );
    assert.strictEqual(
      category.name,
      "Updated category",
      "existing attributes are updated"
    );
    assert.deepEqual(
      page.ancestors,
      [],
      "missing ancestors means an empty list"
    );
  });

  test("explicit false rules are sent and an omitted page uses the server default", async function (assert) {
    let params;
    pretender.post("/categories/search", (request) => {
      params = new URLSearchParams(request.requestBody);
      return response({ categories_count: 0, categories: [] });
    });

    await fetchCategoryPage({
      term: "",
      onlyPostable: false,
      includeSubcategories: true,
      includeUncategorized: true,
    });

    assert.false(params.has("page"), "the default page is left to the server");
    assert.strictEqual(
      params.get("only_postable"),
      "false",
      "false is an explicit rule"
    );
    assert.strictEqual(
      params.get("include_subcategories"),
      "true",
      "true is preserved"
    );
    assert.strictEqual(
      params.get("include_uncategorized"),
      "true",
      "true is preserved"
    );
  });

  test("a failed page rejects without changing the site", async function (assert) {
    const site = Site.current();
    const before = [...site.categories];
    pretender.post("/categories/search", () =>
      response(500, { errors: ["Failed"] })
    );

    await assert.rejects(
      fetchCategoryPage({ term: "failure" }),
      "request errors reach the consumer"
    );
    assert.deepEqual(
      site.categories,
      before,
      "a failed request does not change records"
    );
  });

  test("lazy resolution requests only missing ids and preserves order and duplicates", async function (assert) {
    const site = Site.current();
    site.set("lazy_load_categories", true);
    const known = site.categories[0];
    let requested;
    pretender.get("/categories/find", (request) => {
      requested = new URL(
        request.url,
        window.location.origin
      ).searchParams.getAll("ids[]");
      return response({ categories: [{ id: 9510, name: "Resolved" }] });
    });

    const result = await resolveCategories(["9510", known.id, 9511, 9510]);

    assert.deepEqual(
      requested,
      ["9510", "9511"],
      "only unique missing ids are requested"
    );
    assert.deepEqual(
      result.map((category) => category.id),
      [9510, known.id, 9510],
      "missing ids are dropped without reordering"
    );
    assert.strictEqual(result[1], known, "known records retain identity");
    assert.strictEqual(
      result[0],
      site.categoriesById.get(9510),
      "new records belong to the site"
    );
  });

  test("descendants include a later page's deeper branch in breadth first order", async function (assert) {
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
      });
    });

    const result = await loadDescendants(site.categoriesById.get(9600));

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
      "a level with more children than one page is paged"
    );
    assert.true(
      result.every(
        (category) => site.categoriesById.get(category.id) === category
      ),
      "every descendant is a site record"
    );
  });
});
