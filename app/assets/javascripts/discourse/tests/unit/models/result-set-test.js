import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Model | result-set", function (hooks) {
  setupTest(hooks);

  test("defaults", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = store.createRecord("result-set", { content: [] });
    assert.strictEqual(resultSet.length, 0);
    assert.strictEqual(resultSet.totalRows, 0);
    assert.strictEqual(resultSet.loadMoreUrl, null);
    assert.false(resultSet.loading);
    assert.false(resultSet.loadingMore);
    assert.false(resultSet.refreshing);
  });

  test("pagination support", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = await store.findAll("widget");
    assert.strictEqual(resultSet.length, 2);
    assert.strictEqual(resultSet.totalRows, 4);
    assert.strictEqual(
      resultSet.loadMoreUrl,
      "/load-more-widgets",
      "has a url to load more"
    );
    assert.false(resultSet.loadingMore, "not loading more");
    assert.true(resultSet.canLoadMore);

    const promise = resultSet.loadMore();
    assert.true(resultSet.loadingMore, "is loading more");

    await promise;
    assert.false(resultSet.loadingMore, "finished loading more");
    assert.strictEqual(resultSet.length, 4);
    assert.strictEqual(resultSet.loadMoreUrl, null);
    assert.false(resultSet.canLoadMore);
  });

  test("refresh support", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = await store.findAll("widget");
    assert.strictEqual(
      resultSet.refreshUrl,
      "/widgets?refresh=true",
      "has the refresh url"
    );

    const promise = resultSet.refresh();
    assert.true(resultSet.refreshing, "is refreshing");

    await promise;
    assert.false(resultSet.refreshing, "finished refreshing");
  });
});
