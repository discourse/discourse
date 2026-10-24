import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { serializeTags } from "discourse/lib/serialize-tags";
import {
  findTagIdsByNames,
  resetTagSourceCache,
  searchTags,
} from "discourse/lib/tag-source";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { tagKey } from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";

module("Unit | Utility | serialize-tags", function (hooks) {
  setupTest(hooks);

  test("plain string tag names are serialized as name-only", function (assert) {
    assert.deepEqual(serializeTags(["10"]), [{ name: "10" }]);
    assert.deepEqual(serializeTags(["foo"]), [{ name: "foo" }]);
  });

  test("existing tags with numeric id are serialized with id and name", function (assert) {
    assert.deepEqual(serializeTags([{ id: 10, name: "bulk-test-tag-10" }]), [
      { id: 10, name: "bulk-test-tag-10" },
    ]);
  });

  test("isNew items are serialized as name-only, even when id looks numeric", function (assert) {
    assert.deepEqual(serializeTags([{ id: "10", name: "10", isNew: true }]), [
      { name: "10" },
    ]);
  });

  test("mixed input: existing tag alongside a freshly created numeric-name tag", function (assert) {
    assert.deepEqual(
      serializeTags([
        { id: 42, name: "bulk-test-tag-10" },
        { id: "10", name: "10", isNew: true },
      ]),
      [{ id: 42, name: "bulk-test-tag-10" }, { name: "10" }]
    );
  });

  test("non-numeric id falls back to name-only", function (assert) {
    assert.deepEqual(serializeTags([{ id: "hello", name: "hello" }]), [
      { name: "hello" },
    ]);
  });
});

module(
  "Unit | Utility | serialize-tags | emitted tag values",
  function (hooks) {
    setupTest(hooks);

    hooks.afterEach(function () {
      resetTagSourceCache();
    });

    test("tag keys coerce integer ids but preserve numeric names", function (assert) {
      for (const id of ["1.5", -2, Infinity, "", null, undefined]) {
        assert.strictEqual(
          tagKey({ id, name: "Five" }),
          "tag-name:five",
          `${id} is not a positive integer id`
        );
      }
      assert.strictEqual(
        tagKey({ id: "5e1", name: "Fifty" }),
        50,
        "Number coercion applies"
      );
      assert.strictEqual(tagKey("5e1"), "tag-name:5e1", "strings remain names");
    });

    test("search caps resolved ids and preserves explicit false flags", async function (assert) {
      let params;
      pretender.get("/tags/filter/search", (request) => {
        params = request.queryParams;
        return response({ results: [] });
      });
      await searchTags("", {
        context: {
          selectedTagIds: Array.from({ length: 105 }, (_, index) => index + 1),
          excludeSynonyms: false,
          excludeHasSynonyms: true,
          prioritizeRecentTags: false,
        },
        limit: 2,
        siteSettings: { max_tag_search_results: 5 },
      });
      const ids = params["selected_tag_ids[]"] ?? params.selected_tag_ids;
      assert.strictEqual(ids.length, 100, "selected ids are capped");
      assert.strictEqual(
        ids[99],
        "100",
        "the first hundred retain their order"
      );
      assert.strictEqual(params.limit, "2", "smaller limits are retained");
      assert.strictEqual(
        params.excludeSynonyms,
        "false",
        "explicit false is sent"
      );
      assert.strictEqual(
        params.excludeHasSynonyms,
        "true",
        "synonym exclusion is sent"
      );
      assert.strictEqual(
        params.prioritizeRecentTags,
        "false",
        "explicit recent flag is sent"
      );
      assert.strictEqual(
        params.selected_tags,
        undefined,
        "unresolved names are never sent"
      );
    });

    test("search sorts both row groups unless recent ordering takes priority", async function (assert) {
      pretender.get("/tags/filter/search", () =>
        response({
          results: [
            { id: 1, name: "z", disabled: true, title: "Reason" },
            { id: 2, name: "y" },
            { id: 3, name: "b", disabled: true },
            { id: 4, name: "a", title: "Enabled title" },
          ],
          forbidden_message: "Forbidden reason",
        })
      );
      const siteSettings = {
        max_tag_search_results: 5,
        tags_sort_alphabetically: true,
      };
      const sorted = await searchTags("", { context: {}, siteSettings });
      assert.deepEqual(
        sorted.items.map((row) => row.id),
        [4, 2, 3, 1],
        "both groups sort"
      );
      assert.strictEqual(
        sorted.items[0].description,
        undefined,
        "enabled titles are not reasons"
      );
      assert.strictEqual(
        sorted.forbiddenMessage,
        "Forbidden reason",
        "message is returned"
      );
      const recent = await searchTags("", {
        context: { prioritizeRecentTags: true },
        siteSettings,
      });
      assert.deepEqual(
        recent.items.map((row) => row.id),
        [1, 2, 3, 4],
        "recent order is retained"
      );
    });

    test("name lookup caches normalized sets including misses until reset", async function (assert) {
      let requests = 0;
      pretender.get("/tags/list.json", () => {
        requests++;
        return response({ list_tags: [] });
      });
      assert.deepEqual(
        [...(await findTagIdsByNames([]))],
        [],
        "empty names resolve to no ids"
      );
      assert.strictEqual(requests, 0, "empty names do not request");
      await findTagIdsByNames(["Missing", "OTHER", "Missing"]);
      await findTagIdsByNames(["other", "MISSING"]);
      assert.strictEqual(
        requests,
        1,
        "case, duplicates, order and misses share a cache entry"
      );
      resetTagSourceCache();
      await findTagIdsByNames(["missing", "other"]);
      assert.strictEqual(requests, 2, "reset clears cached misses");
    });
  }
);
