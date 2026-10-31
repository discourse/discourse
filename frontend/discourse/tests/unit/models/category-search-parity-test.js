import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import fixture from "discourse/tests/fixtures/category-search-parity.json";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

const optionNames = {
  only_postable: "onlyPostable",
  parent_category_id: "parentCategoryId",
  include_uncategorized: "includeUncategorized",
  select_category_ids: "selectCategoryIds",
  reject_category_ids: "rejectCategoryIds",
  reject_indirectly_muted: "rejectIndirectlyMuted",
  include_subcategories: "includeSubcategories",
  include_ancestors: "includeAncestors",
  prioritized_category_id: "prioritizedCategoryId",
  group_families: "groupFamilies",
  tree_order: "treeOrder",
  limit: "limit",
  page: "page",
};

function optionsFor(params, ids) {
  return Object.fromEntries(
    Object.entries(params)
      .filter(([name]) => name !== "term")
      .map(([name, value]) => {
        if (
          ["parent_category_id", "prioritized_category_id"].includes(name) &&
          typeof value === "string"
        ) {
          value = ids[value];
        } else if (
          ["select_category_ids", "reject_category_ids"].includes(name)
        ) {
          value = value.map((symbol) => ids[symbol]);
        }
        return [optionNames[name], value];
      })
  );
}

function idsFor(symbols, ids) {
  return symbols.map((symbol) => ids[symbol]);
}

function familyKeysFor(keys, ids) {
  return Object.fromEntries(
    Object.entries(keys).map(([symbol, family]) => [
      ids[symbol],
      family === null ? null : ids[family],
    ])
  );
}

module("Unit | Model | category | search", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser = logIn(this.owner);
    this.currentUser.setProperties({
      admin: false,
      moderator: false,
      staff: false,
    });
    this.site = this.owner.lookup("service:site");
    this.siteSettings = this.owner.lookup("service:site-settings");
    this.siteSettings.allow_uncategorized_topics = false;
    this.siteSettings.fixed_category_positions = false;
    this.ids = Object.fromEntries(
      fixture.categories.map((row, index) => [row.symbol, index + 1])
    );
    this.siteSettings.uncategorized_category_id = this.ids.uncategorized;
    this.currentUser.set(
      "indirectly_muted_category_ids",
      idsFor(fixture.indirectly_muted, this.ids)
    );
    this.site.setProperties({
      categories: [],
      lazy_load_categories: false,
      uncategorized_category_id: this.ids.uncategorized,
      loadedCategoryIds: new Set(),
    });
    const permission = { full: 1, group: 1, reply: 2, readonly: 3 };
    for (const row of fixture.categories.filter(
      (category) => category.visible
    )) {
      this.site.updateCategory({
        id: this.ids[row.symbol],
        name: row.name,
        slug: row.symbol,
        parent_category_id: row.parent ? this.ids[row.parent] : null,
        topic_count: row.topic_count,
        position: row.position,
        permission: permission[row.access],
        read_restricted: row.access === "group",
      });
    }
    Category.clearAsyncSearchCache();
    this.searchRequests = [];
    this.findRequests = [];
    pretender.post("/categories/search", (request) => {
      this.searchRequests.push(new URLSearchParams(request.requestBody));
      return response({ categories: [], ancestors: [], categories_count: 0 });
    });
    pretender.get("/categories/find", (request) => {
      this.findRequests.push(request.queryParams.ids.map((id) => Number(id)));
      return response({ categories: [] });
    });
  });

  for (const searchCase of fixture.cases) {
    test(`matches the shared search fixture: ${searchCase.name}`, function (assert) {
      Object.assign(this.siteSettings, searchCase.settings || {});
      const result = Category.searchCategories(
        searchCase.params.term,
        optionsFor(searchCase.params, this.ids)
      );
      assert.notStrictEqual(
        typeof result?.then,
        "function",
        "the eager answer is synchronous"
      );
      assert.deepEqual(
        Object.keys(result).sort(),
        ["ancestors", "categories", "categoriesCount", "familyKeys"],
        "the public result always has all four fields"
      );
      assert.deepEqual(
        result.categories.map((category) => category.id),
        idsFor(searchCase.expected.categories, this.ids),
        "rows follow the hand-derived order"
      );
      assert.true(
        result.categories.every((category) => category instanceof Category),
        "rows are Category records"
      );
      assert.strictEqual(
        result.categoriesCount,
        searchCase.expected.count,
        "the count is independent of paging"
      );
      assert.deepEqual(
        result.familyKeys,
        searchCase.expected.family_keys
          ? familyKeysFor(searchCase.expected.family_keys, this.ids)
          : undefined,
        "family keys include nulls only when grouping takes effect"
      );
      assert.deepEqual(
        result.ancestors
          .map((category) => category.id)
          .sort((left, right) => left - right),
        idsFor(searchCase.expected.ancestors || [], this.ids).sort(
          (left, right) => left - right
        ),
        "only requested ancestors of returned rows are included"
      );
      assert.true(
        result.ancestors.every((category) => category instanceof Category),
        "ancestors are Category records"
      );
      assert.strictEqual(
        this.searchRequests.length,
        0,
        "no search request is made"
      );
    });
  }

  test("eager asyncSearch keeps its promise and legacy result shapes", async function (assert) {
    const rowsPromise = Category.asyncSearch("ember", { limit: 25 });
    assert.strictEqual(
      typeof rowsPromise.then,
      "function",
      "asyncSearch is always a promise"
    );
    const searchCase = fixture.cases.find(
      (candidate) => candidate.name === "base ranking"
    );
    assert.deepEqual(
      (await rowsPromise).map((category) => category.id),
      idsFor(searchCase.expected.categories, this.ids),
      "the array result uses local ranking"
    );
    const result = await Category.asyncSearch("leaf", {
      includeAncestors: true,
    });
    assert.deepEqual(
      Object.keys(result).sort(),
      ["ancestors", "categories", "categoriesCount"],
      "the legacy ancestor result keeps exactly three fields"
    );
    assert.deepEqual(
      result.categories,
      [Category.findById(this.ids.leaf)],
      "the leaf is returned"
    );
    assert.deepEqual(
      result.ancestors
        .map((category) => category.id)
        .sort((left, right) => left - right),
      idsFor(["root", "branch"], this.ids),
      "both visible ancestors are returned"
    );
    assert.strictEqual(
      result.categoriesCount,
      1,
      "the legacy result includes the count"
    );
    assert.strictEqual(
      this.searchRequests.length,
      0,
      "both calls answer locally"
    );
  });

  test("staff can post in uncategorized when disabled", function (assert) {
    this.currentUser.set("moderator", true);
    const result = Category.searchCategories("un", {
      onlyPostable: true,
      limit: 25,
    });
    assert.deepEqual(
      result.categories.map((category) => category.id),
      idsFor(["uncategorized", "underscore", "underscore_decoy"], this.ids),
      "staff retain Uncategorized while the setting is off"
    );
    assert.strictEqual(
      result.categoriesCount,
      3,
      "all three matching categories are postable for staff"
    );
    assert.strictEqual(
      this.searchRequests.length,
      0,
      "the staff answer is local too"
    );
  });

  test("eager absent limit returns all matches only on page one", function (assert) {
    const searchCase = fixture.cases.find(
      (candidate) => candidate.name === "base ranking"
    );
    const first = Category.searchCategories("ember");
    const second = Category.searchCategories("ember", { page: 2 });
    const later = Category.searchCategories("ember", { page: 9 });
    assert.deepEqual(
      first.categories.map((category) => category.id),
      idsFor(searchCase.expected.categories, this.ids),
      "every match is returned"
    );
    assert.strictEqual(first.categoriesCount, 15, "all matches are counted");
    const capped = fixture.cases.find(
      (candidate) => candidate.name === "limit upper clamp"
    );
    const tail = fixture.cases.find(
      (candidate) => candidate.name === "limit upper clamp page 2"
    );
    const all = Category.searchCategories("");
    assert.deepEqual(
      all.categories.map((category) => category.id),
      idsFor(
        [...capped.expected.categories, ...tail.expected.categories],
        this.ids
      ),
      "an absent limit returns more than 25 rows on an eager site"
    );
    assert.strictEqual(
      all.categoriesCount,
      26,
      "the unlimited count equals the number returned"
    );
    for (const result of [second, later]) {
      assert.deepEqual(result.categories, [], "later pages have no rows");
      assert.strictEqual(
        result.categoriesCount,
        15,
        "later pages retain the full count"
      );
    }
    assert.strictEqual(
      this.searchRequests.length,
      0,
      "unlimited searches stay local"
    );
  });

  test("lazy new options reach the server every time and plain bodies cache", async function (assert) {
    this.site.set("lazy_load_categories", true);
    const requests = [];
    pretender.post("/categories/search", (request) => {
      const params = new URLSearchParams(request.requestBody);
      requests.push(params);
      const familyKeys =
        params.get("group_families") === "true"
          ? { [this.ids.leaf]: this.ids.branch }
          : undefined;
      return response({
        categories: [
          {
            id: this.ids.leaf,
            name: "Ember leaf",
            parent_category_id: this.ids.branch,
          },
        ],
        ancestors: [
          {
            id: this.ids.branch,
            name: "Ember branch",
            parent_category_id: this.ids.root,
          },
        ],
        categories_count: 7,
        ...(familyKeys ? { family_keys: familyKeys } : {}),
      });
    });
    for (const opts of [
      { groupFamilies: true },
      { groupFamilies: false },
      { treeOrder: "topics" },
      { treeOrder: "position" },
      { groupFamilies: true, treeOrder: "topics" },
      {},
    ]) {
      const start = requests.length;
      for (let repeat = 0; repeat < 2; repeat++) {
        const promise = Category.searchCategories("ember", {
          ...opts,
          includeAncestors: true,
          limit: 3,
          page: 2,
        });
        assert.strictEqual(
          typeof promise.then,
          "function",
          "lazy searches return promises"
        );
        const result = await promise;
        assert.deepEqual(
          Object.keys(result).sort(),
          ["ancestors", "categories", "categoriesCount", "familyKeys"],
          "lazy answers have the same four fields"
        );
        assert.deepEqual(
          result.categories,
          [Category.findById(this.ids.leaf)],
          "server rows become records"
        );
        assert.deepEqual(
          result.ancestors,
          [Category.findById(this.ids.branch)],
          "server ancestors become records"
        );
        assert.true(
          result.categories[0] instanceof Category,
          "the row is a Category record"
        );
        assert.true(
          result.ancestors[0] instanceof Category,
          "the ancestor is a Category record"
        );
        assert.strictEqual(
          result.categoriesCount,
          7,
          "the server count survives"
        );
        const expectedFamilyKeys = opts.groupFamilies
          ? { [this.ids.leaf]: this.ids.branch }
          : undefined;
        assert.deepEqual(
          result.familyKeys,
          expectedFamilyKeys,
          "the server family map survives"
        );
      }
      const carriesNewOption =
        Object.hasOwn(opts, "groupFamilies") || opts.treeOrder !== undefined;
      const expectedRequests = carriesNewOption ? 2 : 1;
      assert.strictEqual(
        requests.length - start,
        expectedRequests,
        "only plain requests are cached"
      );
      const expectedTreeOrder = opts.treeOrder ?? null;
      for (const params of requests.slice(start)) {
        assert.strictEqual(
          params.get("group_families"),
          Object.hasOwn(opts, "groupFamilies")
            ? String(opts.groupFamilies)
            : null,
          "group_families is sent exactly when set"
        );
        assert.strictEqual(
          params.get("tree_order"),
          expectedTreeOrder,
          "tree_order is sent exactly when set"
        );
        assert.strictEqual(
          params.get("include_ancestors"),
          "true",
          "ancestor option is sent"
        );
        assert.strictEqual(params.get("limit"), "3", "limit is sent");
        assert.strictEqual(params.get("page"), "2", "page is sent");
      }
    }
    await Category.searchCategories("different-body", { limit: 3 });
    assert.strictEqual(
      requests.at(-1).get("term"),
      "different-body",
      "a different plain body is fetched"
    );
    assert.strictEqual(
      requests.length,
      12,
      "plain caching is keyed by the request body"
    );
  });

  test("lazy result leaves unrequested ancestors and absent family keys empty", async function (assert) {
    this.site.set("lazy_load_categories", true);
    pretender.post("/categories/search", () =>
      response({
        categories: [{ id: this.ids.solo, name: "Ember solo" }],
        categories_count: 1,
      })
    );
    const result = await Category.searchCategories("solo");
    assert.deepEqual(
      result.ancestors,
      [],
      "missing ancestors normalize to an empty array"
    );
    assert.strictEqual(
      result.familyKeys,
      undefined,
      "missing family_keys stays undefined"
    );
    assert.strictEqual(result.categoriesCount, 1, "the count is preserved");
  });

  test("lazy searches send the indirectly muted filter and are never cached", async function (assert) {
    this.site.set("lazy_load_categories", true);
    const requests = [];
    pretender.post("/categories/search", (request) => {
      requests.push(new URLSearchParams(request.requestBody));
      return response({ categories: [], categories_count: 0 });
    });

    await Category.searchCategories("ember", { rejectIndirectlyMuted: true });
    await Category.searchCategories("ember", { rejectIndirectlyMuted: true });

    assert.strictEqual(
      requests.length,
      2,
      "mutes change during a session, so each search asks again"
    );
    assert.strictEqual(
      requests[0].get("reject_indirectly_muted"),
      "true",
      "the filter is sent"
    );
  });

  test("a local search with no current user leaves out nothing", function (assert) {
    this.owner.unregister("service:current-user");
    this.owner.register("service:current-user", null, { instantiate: false });

    const result = Category.searchCategories("", {
      parentCategoryId: this.ids.root,
      rejectIndirectlyMuted: true,
    });

    assert.deepEqual(
      result.categories.map((category) => category.id).sort((a, b) => a - b),
      idsFor(["branch", "sibling"], this.ids),
      "no user means no mutes"
    );
  });

  test("findByIdsOrLoad is synchronous on eager sites and parses string ids", function (assert) {
    const result = Category.findByIdsOrLoad([
      String(this.ids.leaf),
      this.ids.root,
    ]);
    assert.notStrictEqual(
      typeof result?.then,
      "function",
      "eager lookup is synchronous"
    );
    assert.deepEqual(
      result,
      [Category.findById(this.ids.leaf), Category.findById(this.ids.root)],
      "parsed ids preserve request order"
    );
    assert.strictEqual(this.findRequests.length, 0, "no find request is made");
  });

  test("findByIdsOrLoad is synchronous for loaded lazy string ids", function (assert) {
    this.site.setProperties({
      lazy_load_categories: true,
      loadedCategoryIds: new Set([this.ids.root, this.ids.leaf]),
    });
    const result = Category.findByIdsOrLoad([
      String(this.ids.leaf),
      String(this.ids.root),
    ]);
    assert.notStrictEqual(
      typeof result?.then,
      "function",
      "loaded lazy lookup is synchronous"
    );
    assert.deepEqual(
      result,
      [Category.findById(this.ids.leaf), Category.findById(this.ids.root)],
      "numeric strings use loaded records in order"
    );
    assert.strictEqual(
      this.findRequests.length,
      0,
      "loaded ids require no request"
    );
  });

  test("findByIdsOrLoad requests missing lazy ids and becomes synchronous", async function (assert) {
    this.site.setProperties({
      lazy_load_categories: true,
      loadedCategoryIds: new Set([this.ids.root]),
    });
    const missingId = 90001;
    pretender.get("/categories/find", (request) => {
      this.findRequests.push(request.queryParams.ids.map((id) => Number(id)));
      return response({
        categories: [{ id: missingId, name: "Loaded later" }],
      });
    });
    const result = Category.findByIdsOrLoad([String(missingId)]);
    assert.strictEqual(
      typeof result.then,
      "function",
      "a missing id returns a promise"
    );
    assert.deepEqual(
      (await result).map((category) => category.id),
      [missingId],
      "the requested row is fetched"
    );
    assert.deepEqual(
      this.findRequests,
      [[missingId]],
      "only the missing parsed id is requested"
    );
    const loaded = Category.findByIdsOrLoad([String(missingId)]);
    assert.notStrictEqual(
      typeof loaded?.then,
      "function",
      "the next lookup is synchronous"
    );
    assert.strictEqual(
      this.findRequests.length,
      1,
      "the next lookup needs no request"
    );
  });

  test("matchesSearch uses literal case and accent insensitive words", function (assert) {
    const matches = (symbol, term) =>
      Category.matchesSearch(Category.findById(this.ids[symbol]), term);
    assert.true(matches("underscore", "_"), "underscore is literal");
    assert.false(
      matches("underscore_decoy", "_"),
      "underscore is not a wildcard"
    );
    assert.true(matches("percent", "%"), "percent is literal");
    assert.false(matches("percent_decoy", "%"), "percent is not a wildcard");
    assert.true(
      matches("accent", "FACADE SAO MULLER"),
      "common Latin accents fold"
    );
    assert.true(
      matches("plain", "façadé são müller"),
      "accents in the term fold too"
    );
    assert.true(
      matches("forge", "  BLUE\tEmBeR  "),
      "every word matches regardless of position and case"
    );
    assert.false(matches("forge", "blue missing"), "every word is required");
    assert.false(
      matches("blue", "blue\u00a0forge"),
      "non-breaking space stays inside one word"
    );
    assert.true(
      matches("nbsp", "blue\u00a0forge"),
      "a literal non-breaking space matches"
    );
    assert.true(matches("numeric", 123), "terms are stringified");
    assert.true(matches("root", ""), "blank terms match");
    assert.true(matches("root", "CAFE"), "acute e accents fold");
    for (const name of ["first 25 words", "first 250 characters"]) {
      const searchCase = fixture.cases.find(
        (candidate) => candidate.name === name
      );
      assert.deepEqual(
        this.site.categories
          .filter((category) =>
            Category.matchesSearch(category, searchCase.params.term)
          )
          .map((category) => category.id)
          .sort((left, right) => left - right),
        idsFor(searchCase.expected.categories, this.ids).sort(
          (left, right) => left - right
        ),
        `${name} normalization also applies to matchesSearch`
      );
    }
  });

  test("localSearchCategories returns fresh eager arrays and includes later additions", function (assert) {
    const first = Category.localSearchCategories();
    assert.true(Array.isArray(first), "eager categories are an array");
    assert.deepEqual(
      first.map((category) => category.id).sort((left, right) => left - right),
      fixture.categories
        .filter((row) => row.visible)
        .map((row) => this.ids[row.symbol]),
      "every visible category is searchable including the orphan"
    );
    const later = this.site.updateCategory({
      id: 90002,
      name: "Later category",
      permission: 1,
    });
    const second = Category.localSearchCategories();
    assert.notStrictEqual(second, first, "each call returns a fresh array");
    assert.true(second.includes(later), "an appended category is included");
    assert.false(first.includes(later), "an earlier snapshot stays unchanged");
    second.splice(second.indexOf(later), 1);
    assert.true(
      Category.localSearchCategories().includes(later),
      "mutating the returned array does not mutate the site"
    );
    this.site.set("lazy_load_categories", true);
    assert.strictEqual(
      Category.localSearchCategories(),
      undefined,
      "lazy sites have no complete local search set"
    );
  });

  test("topics tree agrees with eager browse except the hidden parent orphan", function (assert) {
    // Site serialization supplies position order; the stable count sort preserves sibling ties.
    this.site.set(
      "categories",
      this.site.categories.toSorted(
        (left, right) =>
          (left.position ?? Infinity) - (right.position ?? Infinity) ||
          left.id - right.id
      )
    );
    const searchCase = fixture.cases.find(
      (candidate) => candidate.name === "tree topics full"
    );
    const first = Category.searchCategories("", {
      treeOrder: "topics",
      limit: 25,
    });
    const last = Category.searchCategories("", {
      treeOrder: "topics",
      limit: 25,
      page: 2,
    });
    const ids = [...first.categories, ...last.categories].map(
      (category) => category.id
    );
    assert.deepEqual(
      first.categories.map((category) => category.id),
      idsFor(searchCase.expected.categories, this.ids),
      "the first page keeps its independent fixture oracle"
    );
    const browseIds = this.site.sortedCategories.map((category) => category.id);
    assert.false(
      browseIds.includes(this.ids.orphan),
      "existing eager browse drops a visible child whose parent is hidden"
    );
    assert.strictEqual(
      ids[0],
      this.ids.orphan,
      "the new tree ranks that child as a root by its topic count"
    );
    assert.deepEqual(
      ids.filter((id) => id !== this.ids.orphan),
      browseIds,
      "all other rows agree with eager browsing"
    );
  });
});
