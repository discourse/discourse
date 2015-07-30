module('store:main');

import createStore from 'helpers/create-store';

test('createRecord', function() {
  const store = createStore();
  const widget = store.createRecord('widget', {id: 111, name: 'hello'});

  ok(!widget.get('isNew'), 'it is not a new record');
  equal(widget.get('name'), 'hello');
  equal(widget.get('id'), 111);
});

test('createRecord without an `id`', function() {
  const store = createStore();
  const widget = store.createRecord('widget', {name: 'hello'});

  ok(widget.get('isNew'), 'it is a new record');
  ok(!widget.get('id'), 'there is no id');
});

test('createRecord without attributes', function() {
  const store = createStore();
  const widget = store.createRecord('widget');

  ok(!widget.get('id'), 'there is no id');
  ok(widget.get('isNew'), 'it is a new record');
});

test('createRecord with a record as attributes returns that record from the map', function() {
  const store = createStore();
  const widget = store.createRecord('widget', {id: 33});
  const secondWidget = store.createRecord('widget', {id: 33});

  equal(widget, secondWidget, 'they should be the same');
});

test('find', function() {
  const store = createStore();
  return store.find('widget', 123).then(function(w) {
    equal(w.get('name'), 'Trout Lure');
    equal(w.get('id'), 123);
    ok(!w.get('isNew'), 'found records are not new');

    // A second find by id returns the same object
    store.find('widget', 123).then(function(w2) {
      equal(w, w2);
    });
  });
});

test('find with object id', function() {
  const store = createStore();
  return store.find('widget', {id: 123}).then(function(w) {
    equal(w.get('firstObject.name'), 'Trout Lure');
  });
});

test('find with query param', function() {
  const store = createStore();
  return store.find('widget', {name: 'Trout Lure'}).then(function(w) {
    equal(w.get('firstObject.id'), 123);
  });
});

test('update', function() {
  const store = createStore();
  return store.update('widget', 123, {name: 'hello'}).then(function(result) {
    ok(result);
  });
});

test('update with a multi world name', function(assert) {
  const store = createStore();
  return store.update('cool-thing', 123, {name: 'hello'}).then(function(result) {
    assert.ok(result);
    assert.equal(result.payload.name, 'hello');
  });
});

test('findAll', function() {
  const store = createStore();
  return store.findAll('widget').then(function(result) {
    equal(result.get('length'), 2);
    const w = result.findBy('id', 124);
    ok(!w.get('isNew'), 'found records are not new');
    equal(w.get('name'), 'Evil Repellant');
  });
});

test('destroyRecord', function(assert) {
  const store = createStore();
  return store.find('widget', 123).then(function(w) {
    store.destroyRecord('widget', w).then(function(result) {
      assert.ok(result);
    });
  });
});

test('find embedded', function() {
  const store = createStore();
  return store.find('fruit', 1).then(function(f) {
    ok(f.get('farmer'), 'it has the embedded object');
    ok(f.get('category'), 'categories are found automatically');
  });
});

test('findAll embedded', function() {
  const store = createStore();
  return store.findAll('fruit').then(function(fruits) {
    equal(fruits.objectAt(0).get('farmer.name'), 'Old MacDonald');
    equal(fruits.objectAt(0).get('farmer'), fruits.objectAt(1).get('farmer'), 'points at the same object');
    equal(fruits.objectAt(2).get('farmer.name'), 'Luke Skywalker');
  });
});
