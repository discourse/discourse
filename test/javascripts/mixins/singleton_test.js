module("Discourse.Singleton");

test("current", function() {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Discourse.Singleton);

  var current = DummyModel.current();
  present(current, 'current returns the current instance');
  equal(current, DummyModel.current(), 'calling it again returns the same instance');
  notEqual(current, DummyModel.create({}), 'we can create other instances that are not the same as current');
});

test("currentProp reading", function() {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Discourse.Singleton);
  var current = DummyModel.current();

  blank(DummyModel.currentProp('evil'), 'by default attributes are blank');
  current.set('evil', 'trout');
  equal(DummyModel.currentProp('evil'), 'trout', 'after changing the instance, the value is set');
});

test("currentProp writing", function() {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Discourse.Singleton);

  blank(DummyModel.currentProp('adventure'), 'by default attributes are blank');
  var result = DummyModel.currentProp('adventure', 'time');
  equal(result, 'time', 'it returns the new value');
  equal(DummyModel.currentProp('adventure'), 'time', 'after calling currentProp the value is set');

  DummyModel.currentProp('count', 0);
  equal(DummyModel.currentProp('count'), 0, 'we can set the value to 0');

  DummyModel.currentProp('adventure', null);
  equal(DummyModel.currentProp('adventure'), null, 'we can set the value to null');
});