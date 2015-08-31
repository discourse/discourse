import { blank, present } from 'helpers/qunit-helpers';
import Singleton from 'discourse/mixins/singleton';

module("mixin:singleton");

test("current", function() {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Singleton);

  var current = DummyModel.current();
  present(current, 'current returns the current instance');
  equal(current, DummyModel.current(), 'calling it again returns the same instance');
  notEqual(current, DummyModel.create({}), 'we can create other instances that are not the same as current');
});

test("currentProp reading", function() {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Singleton);
  var current = DummyModel.current();

  blank(DummyModel.currentProp('evil'), 'by default attributes are blank');
  current.set('evil', 'trout');
  equal(DummyModel.currentProp('evil'), 'trout', 'after changing the instance, the value is set');
});

test("currentProp writing", function() {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Singleton);

  blank(DummyModel.currentProp('adventure'), 'by default attributes are blank');
  var result = DummyModel.currentProp('adventure', 'time');
  equal(result, 'time', 'it returns the new value');
  equal(DummyModel.currentProp('adventure'), 'time', 'after calling currentProp the value is set');

  DummyModel.currentProp('count', 0);
  equal(DummyModel.currentProp('count'), 0, 'we can set the value to 0');

  DummyModel.currentProp('adventure', null);
  equal(DummyModel.currentProp('adventure'), null, 'we can set the value to null');
});

test("createCurrent", function() {
  var Shoe = Ember.Object.extend({});
  Shoe.reopenClass(Singleton, {
    createCurrent: function() {
      return Shoe.create({toes: 5});
    }
  });

  equal(Shoe.currentProp('toes'), 5, 'it created the class using `createCurrent`');
});


test("createCurrent that returns null", function() {
  var Missing = Ember.Object.extend({});
  Missing.reopenClass(Singleton, {
    createCurrent: function() {
      return null;
    }
  });

  blank(Missing.current(), "it doesn't return an instance");
  blank(Missing.currentProp('madeup'), "it won't raise an error asking for a property. Will just return null.");
});
