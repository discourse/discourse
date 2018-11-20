QUnit.module("service:store");

import createStore from "helpers/create-store";

QUnit.test("createRecord", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { id: 111, name: "hello" });

  assert.ok(!widget.get("isNew"), "it is not a new record");
  assert.equal(widget.get("name"), "hello");
  assert.equal(widget.get("id"), 111);
});

QUnit.test("createRecord without an `id`", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { name: "hello" });

  assert.ok(widget.get("isNew"), "it is a new record");
  assert.ok(!widget.get("id"), "there is no id");
});

QUnit.test("createRecord doesn't modify the input `id` field", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { id: 1, name: "hello" });

  const obj = { id: 1, name: "something" };

  const other = store.createRecord("widget", obj);
  assert.equal(widget, other, "returns the same record");
  assert.equal(widget.name, "something", "it updates the properties");
  assert.equal(obj.id, 1, "it does not remove the id from the input");
});

QUnit.test("createRecord without attributes", assert => {
  const store = createStore();
  const widget = store.createRecord("widget");

  assert.ok(!widget.get("id"), "there is no id");
  assert.ok(widget.get("isNew"), "it is a new record");
});

QUnit.test(
  "createRecord with a record as attributes returns that record from the map",
  assert => {
    const store = createStore();
    const widget = store.createRecord("widget", { id: 33 });
    const secondWidget = store.createRecord("widget", { id: 33 });

    assert.equal(widget, secondWidget, "they should be the same");
  }
);

QUnit.test("find", assert => {
  const store = createStore();

  return store.find("widget", 123).then(function(w) {
    assert.equal(w.get("name"), "Trout Lure");
    assert.equal(w.get("id"), 123);
    assert.ok(!w.get("isNew"), "found records are not new");
    assert.equal(w.get("extras.hello"), "world", "extra attributes are set");

    // A second find by id returns the same object
    store.find("widget", 123).then(function(w2) {
      assert.equal(w, w2);
      assert.equal(w.get("extras.hello"), "world", "extra attributes are set");
    });
  });
});

QUnit.test("find with object id", assert => {
  const store = createStore();
  return store.find("widget", { id: 123 }).then(function(w) {
    assert.equal(w.get("firstObject.name"), "Trout Lure");
  });
});

QUnit.test("find with query param", assert => {
  const store = createStore();
  return store.find("widget", { name: "Trout Lure" }).then(function(w) {
    assert.equal(w.get("firstObject.id"), 123);
  });
});

QUnit.test("findStale with no stale results", assert => {
  const store = createStore();
  const stale = store.findStale("widget", { name: "Trout Lure" });

  assert.ok(!stale.hasResults, "there are no stale results");
  assert.ok(!stale.results, "results are present");
  return stale.refresh().then(function(w) {
    assert.equal(
      w.get("firstObject.id"),
      123,
      "a `refresh()` method provides results for stale"
    );
  });
});

QUnit.test("update", assert => {
  const store = createStore();
  return store.update("widget", 123, { name: "hello" }).then(function(result) {
    assert.ok(result);
  });
});

QUnit.test("update with a multi world name", function(assert) {
  const store = createStore();
  return store
    .update("cool-thing", 123, { name: "hello" })
    .then(function(result) {
      assert.ok(result);
      assert.equal(result.payload.name, "hello");
    });
});

QUnit.test("findAll", assert => {
  const store = createStore();
  return store.findAll("widget").then(function(result) {
    assert.equal(result.get("length"), 2);
    const w = result.findBy("id", 124);
    assert.ok(!w.get("isNew"), "found records are not new");
    assert.equal(w.get("name"), "Evil Repellant");
  });
});

QUnit.test("destroyRecord", function(assert) {
  const store = createStore();
  return store.find("widget", 123).then(function(w) {
    store.destroyRecord("widget", w).then(function(result) {
      assert.ok(result);
    });
  });
});

QUnit.test("destroyRecord when new", function(assert) {
  const store = createStore();
  const w = store.createRecord("widget", { name: "hello" });
  store.destroyRecord("widget", w).then(function(result) {
    assert.ok(result);
  });
});

QUnit.test("find embedded", function(assert) {
  const store = createStore();
  return store.find("fruit", 2).then(function(f) {
    assert.ok(f.get("farmer"), "it has the embedded object");

    const fruitCols = f.get("colors");
    assert.equal(fruitCols.length, 2);
    assert.equal(fruitCols[0].get("id"), 1);
    assert.equal(fruitCols[1].get("id"), 2);

    assert.ok(f.get("category"), "categories are found automatically");
  });
});

QUnit.test("meta types", function(assert) {
  const store = createStore();
  return store.find("barn", 1).then(function(f) {
    assert.equal(
      f.get("owner.name"),
      "Old MacDonald",
      "it has the embedded farmer"
    );
  });
});

QUnit.test("findAll embedded", function(assert) {
  const store = createStore();
  return store.findAll("fruit").then(function(fruits) {
    assert.equal(fruits.objectAt(0).get("farmer.name"), "Old MacDonald");
    assert.equal(
      fruits.objectAt(0).get("farmer"),
      fruits.objectAt(1).get("farmer"),
      "points at the same object"
    );
    assert.equal(
      fruits.get("extras.hello"),
      "world",
      "it can supply extra information"
    );

    const fruitCols = fruits.objectAt(0).get("colors");
    assert.equal(fruitCols.length, 2);
    assert.equal(fruitCols[0].get("id"), 1);
    assert.equal(fruitCols[1].get("id"), 2);

    assert.equal(fruits.objectAt(2).get("farmer.name"), "Luke Skywalker");
  });
});
