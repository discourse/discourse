import { module, test } from "qunit";
import ResultSet from "discourse/models/result-set";
import createStore from "discourse/tests/helpers/create-store";

module("Unit | Model | result-set", function () {
  test("defaults", function (assert) {
    const resultSet = ResultSet.create({ content: [] });
    assert.strictEqual(resultSet.get("length"), 0);
    assert.strictEqual(resultSet.get("totalRows"), 0);
    assert.ok(!resultSet.get("loadMoreUrl"));
    assert.ok(!resultSet.get("loading"));
    assert.ok(!resultSet.get("loadingMore"));
    assert.ok(!resultSet.get("refreshing"));
  });

  test("pagination support", async function (assert) {
    const store = createStore();
    const resultSet = await store.findAll("widget");
    assert.strictEqual(resultSet.get("length"), 2);
    assert.strictEqual(resultSet.get("totalRows"), 4);
    assert.ok(resultSet.get("loadMoreUrl"), "has a url to load more");
    assert.ok(!resultSet.get("loadingMore"), "it is not loading more");
    assert.ok(resultSet.get("canLoadMore"));

    const promise = resultSet.loadMore();
    assert.ok(resultSet.get("loadingMore"), "it is loading more");

    await promise;
    assert.ok(!resultSet.get("loadingMore"), "it finished loading more");
    assert.strictEqual(resultSet.get("length"), 4);
    assert.ok(!resultSet.get("loadMoreUrl"));
    assert.ok(!resultSet.get("canLoadMore"));
  });

  test("refresh support", async function (assert) {
    const store = createStore();
    const resultSet = await store.findAll("widget");
    assert.strictEqual(
      resultSet.get("refreshUrl"),
      "/widgets?refresh=true",
      "it has the refresh url"
    );

    const promise = resultSet.refresh();
    assert.ok(resultSet.get("refreshing"), "it is refreshing");

    await promise;
    assert.ok(!resultSet.get("refreshing"), "it is finished refreshing");
  });
});
