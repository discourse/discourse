import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import singleton from "discourse/lib/singleton";

module("Unit | Lib | singleton", function (hooks) {
  setupTest(hooks);

  test("current", function (assert) {
    @singleton
    class DummyModel extends EmberObject {}

    const current = DummyModel.current();
    assert.present(current, "current returns the current instance");
    assert.strictEqual(
      current,
      DummyModel.current(),
      "calling it again returns the same instance"
    );
    assert.notStrictEqual(
      current,
      DummyModel.create({}),
      "we can create other instances that are not the same as current"
    );
  });

  test("currentProp reading", function (assert) {
    @singleton
    class DummyModel extends EmberObject {}

    const current = DummyModel.current();

    assert.blank(
      DummyModel.currentProp("evil"),
      "by default attributes are blank"
    );
    current.set("evil", "trout");
    assert.strictEqual(
      DummyModel.currentProp("evil"),
      "trout",
      "after changing the instance, the value is set"
    );
  });

  test("currentProp writing", function (assert) {
    @singleton
    class DummyModel extends EmberObject {}

    assert.blank(
      DummyModel.currentProp("adventure"),
      "by default attributes are blank"
    );
    let result = DummyModel.currentProp("adventure", "time");
    assert.strictEqual(result, "time", "it returns the new value");
    assert.strictEqual(
      DummyModel.currentProp("adventure"),
      "time",
      "after calling currentProp the value is set"
    );

    DummyModel.currentProp("count", 0);
    assert.strictEqual(
      DummyModel.currentProp("count"),
      0,
      "we can set the value to 0"
    );

    DummyModel.currentProp("adventure", null);
    assert.strictEqual(
      DummyModel.currentProp("adventure"),
      null,
      "we can set the value to null"
    );
  });

  test("createCurrent", function (assert) {
    @singleton
    class Shoe extends EmberObject {
      static createCurrent() {
        return this.create({ toes: 5 });
      }
    }

    assert.strictEqual(
      Shoe.currentProp("toes"),
      5,
      "it created the class using `createCurrent`"
    );
  });

  test("createCurrent that returns null", function (assert) {
    @singleton
    class Missing extends EmberObject {
      static createCurrent() {
        return null;
      }
    }

    assert.blank(Missing.current(), "it doesn't return an instance");
    assert.blank(
      Missing.currentProp("madeup"),
      "it won't raise an error asking for a property. Will just return null."
    );
  });
});
