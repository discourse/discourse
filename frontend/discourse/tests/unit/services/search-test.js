import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | search", function (hooks) {
  setupTest(hooks);

  test("updating the same topic context preserves its search", function (assert) {
    const search = this.owner.lookup("service:search");
    const results = { posts: [{ id: 1 }] };
    search.searchContext = { type: "topic", id: 280 };
    search.inTopicContext = true;
    search.results = results;

    search.searchContext = { type: "topic", id: 280 };

    assert.true(search.inTopicContext, "the same topic stays selected");
    assert.strictEqual(search.results, results, "its results are preserved");
  });

  test("switching topics clears the previous topic's search results", function (assert) {
    const search = this.owner.lookup("service:search");
    search.searchContext = { type: "topic", id: 280 };
    search.inTopicContext = true;
    search.results = { posts: [{ id: 1 }] };
    search.activeGlobalSearchTerm = "猫";

    search.searchContext = { type: "topic", id: 281 };

    assert.false(search.inTopicContext, "the previous topic scope is released");
    assert.deepEqual(
      search.results,
      {},
      "the previous topic's results are cleared"
    );
    assert.strictEqual(
      search.activeGlobalSearchTerm,
      "猫",
      "the query remains available"
    );
  });

  test("changing page context preserves a global search", function (assert) {
    const search = this.owner.lookup("service:search");
    const results = { topics: [{ id: 280 }] };
    search.searchContext = { type: "topic", id: 280 };
    search.results = results;

    search.searchContext = null;

    assert.strictEqual(
      search.results,
      results,
      "global results remain available on other pages"
    );
  });
});
