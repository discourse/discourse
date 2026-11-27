import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Model | result-set", function (hooks) {
  setupTest(hooks);

  test("defaults", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = store.createRecord("result-set", { content: [] });
    assert.strictEqual(
      resultSet.content.length,
      0,
      "should have zero length for empty content array"
    );
    assert.strictEqual(
      resultSet.totalRows,
      0,
      "should have zero total rows by default"
    );
    assert.strictEqual(
      resultSet.loadMoreUrl,
      null,
      "should have null loadMoreUrl by default"
    );
    assert.false(
      resultSet.loading,
      "should not be in loading state by default"
    );
    assert.false(
      resultSet.loadingMore,
      "should not be in loadingMore state by default"
    );
    assert.false(
      resultSet.refreshing,
      "should not be in refreshing state by default"
    );
  });

  test("pagination support", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = await store.findAll("widget");
    assert.strictEqual(
      resultSet.content.length,
      2,
      "initial result set has correct length"
    );
    assert.strictEqual(
      resultSet.totalRows,
      4,
      "total rows match expected value"
    );
    assert.strictEqual(
      resultSet.loadMoreUrl,
      "/load-more-widgets",
      "has a url to load more"
    );
    assert.false(resultSet.loadingMore, "not loading more items initially");
    assert.true(
      resultSet.canLoadMore,
      "can load more items when total exceeds current length"
    );

    const promise = resultSet.loadMore();
    assert.true(
      resultSet.loadingMore,
      "shows loading state while loading more"
    );

    await promise;
    assert.false(resultSet.loadingMore, "finished loading more items");
    assert.strictEqual(
      resultSet.content.length,
      4,
      "result set has expected final length"
    );
    assert.strictEqual(resultSet.loadMoreUrl, null, "no more items to load");
    assert.false(
      resultSet.canLoadMore,
      "cannot load more when total equals length"
    );
  });

  test("pagination without a total", async function (assert) {
    pretender.get("/cats", () =>
      response({ cats: [{ id: 1 }], load_more_cats: "/load-more-cats" })
    );
    pretender.get("/load-more-cats", () => response({ cats: [{ id: 2 }] }));

    const store = getOwner(this).lookup("service:store");
    const resultSet = await store.findAll("cat");
    assert.true(
      resultSet.canLoadMore,
      "can load more while the server sends a load more url"
    );

    await resultSet.loadMore();
    assert.strictEqual(resultSet.content.length, 2, "appends the next page");
    assert.false(
      resultSet.canLoadMore,
      "cannot load more once the server stops sending a load more url"
    );
  });

  test("refresh support", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = await store.findAll("widget");
    assert.strictEqual(
      resultSet.refreshUrl,
      "/widgets?refresh=true",
      "has the correct refresh url"
    );

    const promise = resultSet.refresh();
    assert.true(
      resultSet.refreshing,
      "shows refreshing state while refreshing"
    );

    await promise;
    assert.false(resultSet.refreshing, "finished refreshing the result set");
  });
});
