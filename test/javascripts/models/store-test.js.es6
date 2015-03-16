module('store:main');

import createStore from 'helpers/create-store';

test('createRecord', function() {
  const store = createStore();
  const widget = store.createRecord('widget', {id: 111, name: 'hello'});
  equal(widget.get('name'), 'hello');
  equal(widget.get('id'), 111);
});

test('find', function() {
  const store = createStore();
  store.find('widget', 123).then(function(w) {
    equal(w.get('name'), 'Trout Lure');
    equal(w.get('id'), 123);

    // A second find by id returns the same object
    store.find('widget', 123).then(function(w2) {
      equal(w, w2);
    });
  });
});

test('find with object id', function() {
  const store = createStore();
  store.find('widget', {id: 123}).then(function(w) {
    equal(w.get('firstObject.name'), 'Trout Lure');
  });
});

test('find with query param', function() {
  const store = createStore();
  store.find('widget', {name: 'Trout Lure'}).then(function(w) {
    equal(w.get('firstObject.id'), 123);
  });
});

test('update', function() {
  const store = createStore();
  store.update('widget', 123, {name: 'hello'}).then(function(result) {
    ok(result);
  });
});

test('findAll', function() {
  const store = createStore();
  store.findAll('widget').then(function(result) {
    equal(result.get('length'), 2);
    const w = result.findBy('id', 124);
    equal(w.get('name'), 'Evil Repellant');
  });
});

test('destroyRecord', function() {
  const store = createStore();
  store.find('widget', 123).then(function(w) {
    store.destroyRecord('widget', w).then(function(result) {
      ok(result);
    });
  });
});
