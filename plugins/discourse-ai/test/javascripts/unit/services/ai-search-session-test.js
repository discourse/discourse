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

  test("keeps original matches when a larger rewrite result omits one", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const search = this.owner.lookup("service:search");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const original = await translateResults(searchResults([1, 64334]));
    session.query = "Batterie erweiterung";
    session.scope = { key: "category:1" };
    session.selectedTab = "topics";
    session.topicsResults = original;
    session.contextResults = original;
    search.activeGlobalSearchTerm = session.query;
    search.results = original;
    discoveries.activeRequestId = "current-request";

    pretender.get("/search/query", () => response(searchResults([1, 2, 3])));

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
      [1, 64334],
      "the menu preserves original keyword matches"
    );
    assert.deepEqual(
      search.results.resultTypes[0]?.results.map((post) => post.id),
      [1, 64334],
      "the rendered topic group uses the chosen matches"
    );

    session.selectTab("context");
    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 64334],
      "scoped keyword results preserve original matches too"
    );
  });

  test("accepts a rewrite that retains all original matches", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const search = this.owner.lookup("service:search");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const original = await translateResults(searchResults([1, 64334]));
    session.query = "Batterie erweiterung";
    session.scope = { key: "category:1" };
    session.selectedTab = "topics";
    session.topicsResults = original;
    session.contextResults = original;
    search.activeGlobalSearchTerm = session.query;
    search.results = original;
    discoveries.activeRequestId = "current-request";

    pretender.get("/search/query", () =>
      response(searchResults([1, 2, 64334]))
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
      [1, 2, 64334],
      "the menu preserves original keyword matches"
    );
    assert.deepEqual(
      search.results.resultTypes[0]?.results.map((post) => post.id),
      [1, 2, 64334],
      "the rendered topic group uses the chosen matches"
    );

    session.selectTab("context");
    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 2, 64334],
      "scoped keyword results preserve original matches too"
    );
  });

  test("uses rewritten matches when the original query finds nothing", async function (assert) {
    const session = this.owner.lookup("service:ai-search-session");
    const search = this.owner.lookup("service:search");
    const discoveries = this.owner.lookup("service:discobot-discoveries");
    const original = await translateResults(searchResults([]));
    session.query = "Batterie erweiterung";
    session.scope = { key: "category:1" };
    session.selectedTab = "topics";
    session.topicsResults = original;
    session.contextResults = original;
    search.activeGlobalSearchTerm = session.query;
    search.results = original;
    discoveries.activeRequestId = "current-request";

    pretender.get("/search/query", () => response(searchResults([1, 2])));

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
      [1, 2],
      "the menu preserves original keyword matches"
    );
    assert.deepEqual(
      search.results.resultTypes[0]?.results.map((post) => post.id),
      [1, 2],
      "the rendered topic group uses the chosen matches"
    );

    session.selectTab("context");
    assert.deepEqual(
      search.results.posts.map((post) => post.id),
      [1, 2],
      "scoped keyword results preserve original matches too"
    );
  });
});
