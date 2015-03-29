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
});

test('pagination support', function() {
  const store = createStore();
  store.findAll('widget').then(function(rs) {
    equal(rs.get('length'), 2);
    equal(rs.get('totalRows'), 4);
    ok(rs.get('loadMoreUrl'), 'has a url to load more');

    rs.loadMore().then(function() {
      equal(rs.get('length'), 4);
      ok(!rs.get('loadMoreUrl'));
    });
  });

});
