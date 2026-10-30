import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import * as tagSource from "discourse/lib/tag-source";
import {
  cleanTagName,
  findTagIdsByNames,
  resetTagSourceCache,
  searchTagGroups,
  searchTags,
  sortTagRows,
  topTags,
} from "discourse/lib/tag-source";
import cleanParity from "discourse/tests/fixtures/tag-clean-parity.json";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

const SETTINGS = {
  max_tag_search_results: 5,
  tags_sort_alphabetically: false,
  max_tag_length: 20,
  force_lowercase_tags: false,
};

module("Unit | lib | tag-source", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    resetTagSourceCache();
  });

  test("searchTags sends the loader context", async function (assert) {
    let params;
    pretender.get("/tags/filter/search", (request) => {
      params = request.queryParams;
      return response({
        results: [{ id: 1, name: "bug", text: "bug", count: 4 }],
      });
    });

    const result = await searchTags("ba", {
      context: {
        categoryId: 3,
        everyTag: false,
        selectedTagIds: [1, 2],
        excludeSynonyms: true,
      },
      limit: 50,
      siteSettings: SETTINGS,
    });

    assert.strictEqual(params.q, "ba");
    assert.strictEqual(
      params.limit,
      "5",
      "the limit is clamped to the site maximum"
    );
    assert.strictEqual(params.categoryId, "3");
    const selected = params["selected_tag_ids[]"] ?? params.selected_tag_ids;
    assert.deepEqual(selected, ["1", "2"]);
    assert.strictEqual(params.filterForInput, "true");
    assert.strictEqual(params.excludeSynonyms, "true");
    assert.deepEqual(result.items, [
      { id: 1, name: "bug", text: "bug", count: 4 },
    ]);
  });

  test("everyTag skips the input filter", async function (assert) {
    let params;
    pretender.get("/tags/filter/search", (request) => {
      params = request.queryParams;
      return response({ results: [] });
    });

    await searchTags("", {
      context: { everyTag: true },
      siteSettings: SETTINGS,
    });

    assert.strictEqual(params.filterForInput, undefined);
  });

  test("a disabled row's reason becomes its description", async function (assert) {
    pretender.get("/tags/filter/search", () =>
      response({
        results: [
          {
            id: 2,
            name: "child",
            text: "child",
            count: 0,
            disabled: true,
            title: "Requires parent",
          },
        ],
        forbidden: "nope",
        forbidden_message: "Not allowed",
        required_tag_group: { name: "Kind", min_count: 1, remaining_count: 1 },
      })
    );

    const result = await searchTags("ch", {
      context: {},
      siteSettings: SETTINGS,
    });

    assert.true(result.items[0].disabled);
    assert.strictEqual(result.items[0].description, "Requires parent");
    assert.strictEqual(result.forbidden, "nope");
    assert.deepEqual(result.requiredTagGroup, {
      name: "Kind",
      min_count: 1,
      remaining_count: 1,
    });
  });

  test("a failed search rejects", async function (assert) {
    pretender.get("/tags/filter/search", () => response(500, {}));

    await assert.rejects(
      searchTags("x", { context: {}, siteSettings: SETTINGS })
    );
  });

  test("sortTagRows puts enabled rows first, alphabetically when asked", function (assert) {
    const rows = [
      { name: "zeta" },
      { name: "beta", disabled: true },
      { name: "alpha" },
    ];
    assert.deepEqual(
      sortTagRows(rows, { alphabetical: true }).map((r) => r.name),
      ["alpha", "zeta", "beta"]
    );
    assert.strictEqual(
      sortTagRows(rows, { alphabetical: false }),
      rows,
      "untouched otherwise"
    );
  });

  test("sortTagRows keeps an exact match first, by its stored name", function (assert) {
    const rows = [
      { name: "rock-band" },
      { name: "Roca", original_name: "rock" },
      { name: "alpha" },
      { name: "rock-off", disabled: true },
    ];

    assert.deepEqual(
      sortTagRows(rows, { alphabetical: true, exact: "ROCK" }).map(
        (r) => r.name
      ),
      ["Roca", "alpha", "rock-band", "rock-off"]
    );
  });

  test("searchTags compares the cleaned term when sorting alphabetically", async function (assert) {
    pretender.get("/tags/filter/search", () =>
      response({
        results: [
          { id: 1, name: "rock" },
          { id: 2, name: "rock-band" },
          { id: 3, name: "alpha-rock" },
        ],
      })
    );

    const result = await searchTags("Rock!", {
      context: {},
      siteSettings: { ...SETTINGS, tags_sort_alphabetically: true },
    });

    assert.deepEqual(
      result.items.map((r) => r.name),
      ["rock", "alpha-rock", "rock-band"]
    );
  });

  test("cleanTagName mirrors the server's clean_tag", function (assert) {
    assert.strictEqual(cleanTagName("  Foo Bar!! ", SETTINGS), "Foo-Bar");
    assert.strictEqual(
      cleanTagName("Foo Bar", { ...SETTINGS, force_lowercase_tags: true }),
      "foo-bar"
    );
    assert.strictEqual(
      cleanTagName("a".repeat(30), SETTINGS),
      "a".repeat(20),
      "max length applies"
    );
    assert.strictEqual(cleanTagName("..dots..", SETTINGS), "dots");
  });

  for (const row of cleanParity.cases) {
    test(`cleanTagName parity: ${row.name}`, function (assert) {
      const settings = { ...cleanParity.settings };
      for (const key of Object.keys(settings)) {
        if (key in row) {
          settings[key] = row[key];
        }
      }

      assert.strictEqual(cleanTagName(row.input, settings), row.expected);
    });
  }

  test("findTagIdsByNames resolves names to ids, cached", async function (assert) {
    const requests = [];
    pretender.get("/tags/list.json", (request) => {
      requests.push(request.queryParams.only_tags);
      return response({
        list_tags: [
          { id: 4, name: "Localized A" },
          { id: 8, name: "b" },
        ],
      });
    });

    const ids = await findTagIdsByNames(["A", "b", "missing"]);
    assert.deepEqual(
      [...ids].sort(),
      [4, 8],
      "ids are returned as a set, names ignored"
    );

    await findTagIdsByNames(["b", "missing", "A"]);
    assert.strictEqual(
      requests.length,
      1,
      "the same names are cached in any order"
    );
  });

  test("findTagIdsByNames chunks at the endpoint's page size", async function (assert) {
    const requests = [];
    pretender.get("/tags/list.json", (request) => {
      requests.push(request.queryParams.only_tags.split(",").length);
      return response({ list_tags: [] });
    });

    const names = Array.from({ length: 60 }, (_, i) => `t${i}`);
    await findTagIdsByNames(names);

    assert.deepEqual(requests, [51, 9]);
  });

  test("searchTagGroups keys groups by name", async function (assert) {
    let params;
    pretender.get("/tag_groups/filter/search", (request) => {
      params = request.queryParams;
      return response({ results: [{ name: "Kind", tags: [] }] });
    });

    const items = await searchTagGroups("ki", { siteSettings: SETTINGS });

    assert.strictEqual(params.q, "ki");
    assert.deepEqual(items, [{ id: "Kind", name: "Kind" }]);
  });

  test("topTags prefers the category's top tags", function (assert) {
    const site = { top_tags: ["a", "b"], category_top_tags: ["c"] };
    assert.deepEqual(topTags({ site, categoryId: 3 }), ["c"]);
    assert.deepEqual(topTags({ site }), ["a", "b"]);
    assert.deepEqual(topTags({ site: {} }), []);
  });

  test("prefers the stored name over a translated one", function (assert) {
    assert.strictEqual(
      tagSource.storedName?.({
        id: 1,
        name: "戦略",
        original_name: "strategy",
      }),
      "strategy",
      "a translated row yields its stored name"
    );
    assert.strictEqual(
      tagSource.storedName?.({ id: 2, name: "design" }),
      "design",
      "an untranslated row yields its name"
    );
  });

  test("search keeps original_name on its rows", async function (assert) {
    pretender.get("/tags/filter/search", () =>
      response({
        results: [{ id: 1, name: "戦略", original_name: "strategy" }],
      })
    );

    const { items } = await searchTags("st", {
      context: {},
      siteSettings: SETTINGS,
    });

    assert.strictEqual(items[0].original_name, "strategy");
  });
});
