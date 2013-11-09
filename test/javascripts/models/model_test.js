module("Discourse.Model");

test("mixes in Discourse.Presence", function() {
  ok(Discourse.Presence.detect(Discourse.Model.create()));
});

test("mergeAttributes: merges attributes from another object", function() {
  var model = Discourse.Model.create({
    foo: "foo",
    bar: "original bar"
  });

  model.mergeAttributes({
    bar: "merged bar",
    baz: "baz"
  });

  equal(model.get("foo"), "foo", "leaving original attr intact when only original object contains given key");
  equal(model.get("bar"), "merged bar", "overwriting original attr when both objects contain given key");
  equal(model.get("baz"), "baz", "adding new attr to original object when only merged object contains given key");
});

test("mergeAttributes: respects Ember setters (so observers etc. work)", function() {
  var observerHasFired = false;

  var model = Discourse.Model.create({foo: "original foo"});
  model.addObserver("foo", function() {
    observerHasFired = true;
  });
  model.mergeAttributes({foo: "merged foo"});

  ok(observerHasFired);
});

test("extractByKey: converts a list of hashes into a hash of instances of specified class, indexed by their ids", function() {
  var firstObject = {id: "id_1", foo: "foo_1"};
  var secondObject = {id: "id_2", foo: "foo_2"};

  var actual = Discourse.Model.extractByKey([firstObject, secondObject], Ember.Object);
  var expected = {
    id_1: Ember.Object.create(firstObject),
    id_2: Ember.Object.create(secondObject)
  };

  ok(_.isEqual(actual, expected));
});

test("extractByKey: returns an empty hash if there isn't anything to convert", function() {
  deepEqual(Discourse.Model.extractByKey(), {}, "when called without parameters");
  deepEqual(Discourse.Model.extractByKey([]), {}, "when called with an empty array");
});
