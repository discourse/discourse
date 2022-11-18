import { module, test } from "qunit";
import { getOwner } from "discourse-common/lib/get-owner";
import { setupTest } from "ember-qunit";

module("Unit | Model | result-set", function (hooks) {
  setupTest(hooks);

  test("defaults", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = store.createRecord("result-set", { content: [] });
    assert.strictEqual(resultSet.length, 0);
    assert.strictEqual(resultSet.totalRows, 0);
    assert.ok(!resultSet.loadMoreUrl);
    assert.ok(!resultSet.loading);
    assert.ok(!resultSet.loadingMore);
    assert.ok(!resultSet.refreshing);
  });

  test("pagination support", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = await store.findAll("widget");
    assert.strictEqual(resultSet.length, 2);
    assert.strictEqual(resultSet.totalRows, 4);
    assert.ok(resultSet.loadMoreUrl, "has a url to load more");
    assert.ok(!resultSet.loadingMore, "it is not loading more");
    assert.ok(resultSet.canLoadMore);

    const promise = resultSet.loadMore();
    assert.ok(resultSet.loadingMore, "it is loading more");

    await promise;
    assert.ok(!resultSet.loadingMore, "it finished loading more");
    assert.strictEqual(resultSet.length, 4);
    assert.ok(!resultSet.loadMoreUrl);
    assert.ok(!resultSet.canLoadMore);
  });

  test("refresh support", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const resultSet = await store.findAll("widget");
    assert.strictEqual(
      resultSet.refreshUrl,
      "/widgets?refresh=true",
      "it has the refresh url"
    );

    const promise = resultSet.refresh();
    assert.ok(resultSet.refreshing, "it is refreshing");

    await promise;
    assert.ok(!resultSet.refreshing, "it is finished refreshing");
  });
});
