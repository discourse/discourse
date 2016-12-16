module('result-set');

import ResultSet from 'discourse/models/result-set';
import createStore from 'helpers/create-store';

test('defaults', function() {
  const rs = ResultSet.create({ content: [] });
  equal(rs.get('length'), 0);
  equal(rs.get('totalRows'), 0);
  ok(!rs.get('loadMoreUrl'));
  ok(!rs.get('loading'));
  ok(!rs.get('loadingMore'));
  ok(!rs.get('refreshing'));
});

test('pagination support', function() {
  const store = createStore();
  store.findAll('widget').then(function(rs) {
    equal(rs.get('length'), 2);
    equal(rs.get('totalRows'), 4);
    ok(rs.get('loadMoreUrl'), 'has a url to load more');
    ok(!rs.get('loadingMore'), 'it is not loading more');
    ok(rs.get('canLoadMore'));

    const promise = rs.loadMore();

    ok(rs.get('loadingMore'), 'it is loading more');
    promise.then(function() {
      ok(!rs.get('loadingMore'), 'it finished loading more');
      equal(rs.get('length'), 4);
      ok(!rs.get('loadMoreUrl'));
      ok(!rs.get('canLoadMore'));
    });
  });
});

test('refresh support', function() {
  const store = createStore();
  store.findAll('widget').then(function(rs) {
    equal(rs.get('refreshUrl'), '/widgets?refresh=true', 'it has the refresh url');

    const promise = rs.refresh();

    ok(rs.get('refreshing'), 'it is refreshing');
    promise.then(function() {
      ok(!rs.get('refreshing'), 'it is finished refreshing');
    });
  });
});
