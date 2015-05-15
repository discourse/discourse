module('rest-model');

import createStore from 'helpers/create-store';
import RestModel from 'discourse/models/rest';

test('munging', function() {
  const store = createStore();
  const Grape = RestModel.extend();
  Grape.reopenClass({
    munge: function(json) {
      json.inverse = 1 - json.percent;
      return json;
    }
  });

  var g = Grape.create({ store, percent: 0.4 });
  equal(g.get('inverse'), 0.6, 'it runs `munge` on `create`');
});

test('update', function() {
  const store = createStore();
  return store.find('widget', 123).then(function(widget) {
    equal(widget.get('name'), 'Trout Lure');

    ok(!widget.get('isSaving'));
    const promise = widget.update({ name: 'new name' });
    ok(widget.get('isSaving'));
    promise.then(function() {
      ok(!widget.get('isSaving'));
      equal(widget.get('name'), 'new name');
    });
  });
});

test('updating simultaneously', function() {
  expect(2);

  const store = createStore();
  return store.find('widget', 123).then(function(widget) {

    const firstPromise = widget.update({ name: 'new name' });
    const secondPromise = widget.update({ name: 'new name' });
    firstPromise.then(function() {
      ok(true, 'the first promise succeeeds');
    });

    secondPromise.catch(function() {
      ok(true, 'the second promise fails');
    });
  });
});

test('save new', function() {
  const store = createStore();
  const widget = store.createRecord('widget');

  ok(widget.get('isNew'), 'it is a new record');
  ok(!widget.get('isCreated'), 'it is not created');
  ok(!widget.get('isSaving'));

  const promise = widget.save({ name: 'Evil Widget' });
  ok(widget.get('isSaving'));

  return promise.then(function() {
    ok(!widget.get('isSaving'));
    ok(widget.get('id'), 'it has an id');
    ok(widget.get('name'), 'Evil Widget');
    ok(widget.get('isCreated'), 'it is created');
    ok(!widget.get('isNew'), 'it is no longer new');
  });
});

test('creating simultaneously', function() {
  expect(2);

  const store = createStore();
  const widget = store.createRecord('widget');

  const firstPromise = widget.save({ name: 'Evil Widget' });
  const secondPromise = widget.save({ name: 'Evil Widget' });
  firstPromise.then(function() {
    ok(true, 'the first promise succeeeds');
  });

  secondPromise.catch(function() {
    ok(true, 'the second promise fails');
  });
});

test('destroyRecord', function() {
  const store = createStore();
  return store.find('widget', 123).then(function(widget) {
    widget.destroyRecord().then(function(result) {
      ok(result);
    });
  });
});

