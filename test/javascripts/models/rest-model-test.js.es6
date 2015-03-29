module('rest-model');

import createStore from 'helpers/create-store';

test('update', function() {
  const store = createStore();

  store.find('widget', 123).then(function(widget) {
    equal(widget.get('name'), 'Trout Lure');
    widget.update({ name: 'new name' }).then(function() {
      equal(widget.get('name'), 'new name');
    });
  });
});

test('destroyRecord', function() {
  const store = createStore();
  store.find('widget', 123).then(function(widget) {
    widget.destroyRecord().then(function(result) {
      ok(result);
    });
  });
});

