module("Discourse.SortOrder");

test('defaults', function() {
  var sortOrder = Discourse.SortOrder.create();
  equal(sortOrder.get('order'), 'default', 'it is `default` by default');
  equal(sortOrder.get('descending'), true, 'it is descending by default');
});

test('toggle', function() {
  var sortOrder = Discourse.SortOrder.create();

  sortOrder.toggle('default');
  equal(sortOrder.get('descending'), false, 'if we toggle the same name it swaps the asc/desc');

  sortOrder.toggle('name');
  equal(sortOrder.get('order'), 'name', 'it changes the order');
  equal(sortOrder.get('descending'), true, 'when toggling names it switches back to descending');

  sortOrder.toggle('name');
  sortOrder.toggle('name');
  equal(sortOrder.get('descending'), true, 'toggling twice goes back to descending');

});