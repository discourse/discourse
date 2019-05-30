QUnit.module("result-set");

import ResultSet from "discourse/models/result-set";
import createStore from "helpers/create-store";

QUnit.test("defaults", assert => {
  const rs = ResultSet.create({ content: [] });
  assert.equal(rs.length, 0);
  assert.equal(rs.totalRows, 0);
  assert.ok(!rs.loadMoreUrl);
  assert.ok(!rs.loading);
  assert.ok(!rs.loadingMore);
  assert.ok(!rs.refreshing);
});

QUnit.test("pagination support", assert => {
  const store = createStore();
  return store.findAll("widget").then(function(rs) {
    assert.equal(rs.length, 2);
    assert.equal(rs.totalRows, 4);
    assert.ok(rs.loadMoreUrl, "has a url to load more");
    assert.ok(!rs.loadingMore, "it is not loading more");
    assert.ok(rs.canLoadMore);

    const promise = rs.loadMore();

    assert.ok(rs.loadingMore, "it is loading more");
    promise.then(function() {
      assert.ok(!rs.loadingMore, "it finished loading more");
      assert.equal(rs.length, 4);
      assert.ok(!rs.loadMoreUrl);
      assert.ok(!rs.canLoadMore);
    });
  });
});

QUnit.test("refresh support", assert => {
  const store = createStore();
  return store.findAll("widget").then(function(rs) {
    assert.equal(
      rs.refreshUrl,
      "/widgets?refresh=true",
      "it has the refresh url"
    );

    const promise = rs.refresh();

    assert.ok(rs.refreshing, "it is refreshing");
    promise.then(function() {
      assert.ok(!rs.refreshing, "it is finished refreshing");
    });
  });
});
