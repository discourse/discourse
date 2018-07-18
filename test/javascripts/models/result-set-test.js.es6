QUnit.module("result-set");

import ResultSet from "discourse/models/result-set";
import createStore from "helpers/create-store";

QUnit.test("defaults", assert => {
  const rs = ResultSet.create({ content: [] });
  assert.equal(rs.get("length"), 0);
  assert.equal(rs.get("totalRows"), 0);
  assert.ok(!rs.get("loadMoreUrl"));
  assert.ok(!rs.get("loading"));
  assert.ok(!rs.get("loadingMore"));
  assert.ok(!rs.get("refreshing"));
});

QUnit.test("pagination support", assert => {
  const store = createStore();
  return store.findAll("widget").then(function(rs) {
    assert.equal(rs.get("length"), 2);
    assert.equal(rs.get("totalRows"), 4);
    assert.ok(rs.get("loadMoreUrl"), "has a url to load more");
    assert.ok(!rs.get("loadingMore"), "it is not loading more");
    assert.ok(rs.get("canLoadMore"));

    const promise = rs.loadMore();

    assert.ok(rs.get("loadingMore"), "it is loading more");
    promise.then(function() {
      assert.ok(!rs.get("loadingMore"), "it finished loading more");
      assert.equal(rs.get("length"), 4);
      assert.ok(!rs.get("loadMoreUrl"));
      assert.ok(!rs.get("canLoadMore"));
    });
  });
});

QUnit.test("refresh support", assert => {
  const store = createStore();
  return store.findAll("widget").then(function(rs) {
    assert.equal(
      rs.get("refreshUrl"),
      "/widgets?refresh=true",
      "it has the refresh url"
    );

    const promise = rs.refresh();

    assert.ok(rs.get("refreshing"), "it is refreshing");
    promise.then(function() {
      assert.ok(!rs.get("refreshing"), "it is finished refreshing");
    });
  });
});
