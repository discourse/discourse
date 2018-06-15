import Model from "discourse/models/model";

QUnit.module("model:discourse");

QUnit.test(
  "extractByKey: converts a list of hashes into a hash of instances of specified class, indexed by their ids",
  assert => {
    var firstObject = { id: "id_1", foo: "foo_1" };
    var secondObject = { id: "id_2", foo: "foo_2" };

    var actual = Model.extractByKey([firstObject, secondObject], Ember.Object);
    var expected = {
      id_1: Ember.Object.create(firstObject),
      id_2: Ember.Object.create(secondObject)
    };

    assert.ok(_.isEqual(actual, expected));
  }
);

QUnit.test(
  "extractByKey: returns an empty hash if there isn't anything to convert",
  assert => {
    assert.deepEqual(
      Model.extractByKey(),
      {},
      "when called without parameters"
    );
    assert.deepEqual(
      Model.extractByKey([]),
      {},
      "when called with an empty array"
    );
  }
);
