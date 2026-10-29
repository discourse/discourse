import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { translateResults } from "discourse/lib/search";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

function searchResults(ids) {
  return {
    posts: ids.map((id) => ({ id, topic_id: id, blurb: "Battery expansion" })),
    topics: ids.map((id) => ({ id, title: "Battery expansion" })),
    grouped_search_result: {},
  };
}

module("Unit | Service | ai-search-session", function (hooks) {
  setupTest(hooks);

  for (const scenario of [
    {
      name: "keeps original matches when a larger rewrite result omits one",
      original: [1, 64334],
      rewritten: [1, 2, 3],
      expected: [1, 64334],
    },
    {
      name: "accepts a rewrite that retains all original matches",
      original: [1, 64334],
      rewritten: [1, 2, 64334],
      expected: [1, 2, 64334],
    },
    {
      name: "uses rewritten matches when the original query finds nothing",
      original: [],
      rewritten: [1, 2],
      expected: [1, 2],
    },
  ]) {
    test(scenario.name, async function (assert) {
      const session = this.owner.lookup("service:ai-search-session");
      const search = this.owner.lookup("service:search");
      const discoveries = this.owner.lookup("service:discobot-discoveries");
      const original = await translateResults(searchResults(scenario.original));
      session.query = "Batterie erweiterung";
      session.scope = { key: "category:1" };
      session.selectedTab = "topics";
      session.topicsResults = original;
      session.contextResults = original;
      search.activeGlobalSearchTerm = session.query;
      search.results = original;
      discoveries.activeRequestId = "current-request";

      pretender.get("/search/query", () =>
        response(searchResults(scenario.rewritten))
      );

      session.onDiscovery({
        query: session.query,
        request_id: discoveries.activeRequestId,
        phase: "rewritten",
        keyword_query: "battery expansion",
      });
      discoveries.cancelDiscoveryTimeout();
      await settled();

      assert.deepEqual(
        search.results.posts.map((post) => post.id),
        scenario.expected,
        "the menu preserves original keyword matches"
      );
      assert.deepEqual(
        search.results.resultTypes[0]?.results.map((post) => post.id),
        scenario.expected,
        "the rendered topic group uses the chosen matches"
      );

      session.selectTab("context");
      assert.deepEqual(
        search.results.posts.map((post) => post.id),
        scenario.expected,
        "scoped keyword results preserve original matches too"
      );
    });
  }
});
