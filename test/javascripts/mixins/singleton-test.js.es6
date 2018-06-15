import Singleton from "discourse/mixins/singleton";

QUnit.module("mixin:singleton");

QUnit.test("current", assert => {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Singleton);

  var current = DummyModel.current();
  assert.present(current, "current returns the current instance");
  assert.equal(
    current,
    DummyModel.current(),
    "calling it again returns the same instance"
  );
  assert.notEqual(
    current,
    DummyModel.create({}),
    "we can create other instances that are not the same as current"
  );
});

QUnit.test("currentProp reading", assert => {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Singleton);
  var current = DummyModel.current();

  assert.blank(
    DummyModel.currentProp("evil"),
    "by default attributes are blank"
  );
  current.set("evil", "trout");
  assert.equal(
    DummyModel.currentProp("evil"),
    "trout",
    "after changing the instance, the value is set"
  );
});

QUnit.test("currentProp writing", assert => {
  var DummyModel = Ember.Object.extend({});
  DummyModel.reopenClass(Singleton);

  assert.blank(
    DummyModel.currentProp("adventure"),
    "by default attributes are blank"
  );
  var result = DummyModel.currentProp("adventure", "time");
  assert.equal(result, "time", "it returns the new value");
  assert.equal(
    DummyModel.currentProp("adventure"),
    "time",
    "after calling currentProp the value is set"
  );

  DummyModel.currentProp("count", 0);
  assert.equal(DummyModel.currentProp("count"), 0, "we can set the value to 0");

  DummyModel.currentProp("adventure", null);
  assert.equal(
    DummyModel.currentProp("adventure"),
    null,
    "we can set the value to null"
  );
});

QUnit.test("createCurrent", assert => {
  var Shoe = Ember.Object.extend({});
  Shoe.reopenClass(Singleton, {
    createCurrent: function() {
      return Shoe.create({ toes: 5 });
    }
  });

  assert.equal(
    Shoe.currentProp("toes"),
    5,
    "it created the class using `createCurrent`"
  );
});

QUnit.test("createCurrent that returns null", assert => {
  var Missing = Ember.Object.extend({});
  Missing.reopenClass(Singleton, {
    createCurrent: function() {
      return null;
    }
  });

  assert.blank(Missing.current(), "it doesn't return an instance");
  assert.blank(
    Missing.currentProp("madeup"),
    "it won't raise an error asking for a property. Will just return null."
  );
});
