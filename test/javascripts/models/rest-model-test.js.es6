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

  store.find('widget', 123).then(function(widget) {
    equal(widget.get('name'), 'Trout Lure');
    widget.update({ name: 'new name' }).then(function() {
      equal(widget.get('name'), 'new name');
    });
  });
});

test('save new', function() {
  const store = createStore();
  const widget = store.createRecord('widget');

  ok(widget.get('isNew'), 'it is a new record');
  ok(!widget.get('isCreated'), 'it is not created');

  widget.save({ name: 'Evil Widget' }).then(function() {
    ok(widget.get('id'), 'it has an id');
    ok(widget.get('name'), 'Evil Widget');
    ok(widget.get('isCreated'), 'it is created');
    ok(!widget.get('isNew'), 'it is no longer new');
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

