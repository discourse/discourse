QUnit.module("service:store");

import createStore from "helpers/create-store";

QUnit.test("createRecord", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { id: 111, name: "hello" });

  assert.ok(!widget.get("isNew"), "record is not new");
  assert.equal(widget.get("name"), "hello", "record name is correct");
  assert.equal(widget.get("id"), 111, "record ID is correct");
});

QUnit.test("createRecord with ID 0", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { id: 0, name: "" });

  assert.ok(!widget.get("isNew"), "record is not new");
  assert.equal(widget.get("name"), "", "record name is correct");
  assert.equal(widget.get("id"), 0, "record ID is correct");
});

QUnit.test("createRecord without an ID", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { name: "hello" });

  assert.ok(widget.get("isNew"), "record is new");
  assert.ok(widget.get("id") === undefined, "record has no `id` property");
});

QUnit.test("createRecord doesn’t modify the input `id` field", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { id: 1, name: "hello" });

  const obj = { id: 1, name: "something" };
  const other = store.createRecord("widget", obj);

  assert.deepEqual(widget, other, "both records are the same");
  assert.equal(widget.name, "something", "it updates the properties");
  assert.equal(obj.id, 1, "it does not remove the id from the input");
});

QUnit.test("createRecord without attributes", assert => {
  const store = createStore();
  const widget = store.createRecord("widget");

  assert.ok(widget.get("id") === undefined, "record has no `id` property");
  assert.ok(widget.get("isNew"), "record is new");
  assert.ok(!widget.get("isCreated"), "record is not created");
});

QUnit.test(
  "createRecord with a record as attributes returns that record from the map",
  assert => {
    const store = createStore();
    const widget = store.createRecord("widget", { id: 33 });
    const other = store.createRecord("widget", { id: 33 });

    assert.deepEqual(widget, other, "both records are the same");
  }
);

QUnit.test("find", assert => {
  const store = createStore();
  return store.find("widget", 123).then(result1 => {
    assert.equal(result1.get("name"), "Trout Lure", "record name is correct");
    assert.equal(result1.get("id"), 123, "record ID is correct");
    assert.ok(!result1.get("isNew"), "record is not new");
    assert.equal(result1.get("extras.hello"), "world", "extra attributes are set");

    // A second find by id returns the same object
    store.find("widget", 123).then(result2 => {
      assert.deepEqual(result1, result2, "Second `find` returns the same object");
      assert.equal(result1.get("extras.hello"), "world", "extra attributes are set");
    });
  });
});

QUnit.test("find with object id", assert => {
  const store = createStore();
  return store.find("widget", { id: 123 }).then(result => {
    assert.equal(result.get("firstObject.name"), "Trout Lure", "record name is correct");
  });
});

QUnit.test("find with query param", assert => {
  const store = createStore();
  return store.find("widget", { name: "Trout Lure" }).then(result => {
    assert.equal(result.get("firstObject.id"), 123, "record ID is correct");
  });
});

QUnit.test("findStale with no stale results", assert => {
  const store = createStore();
  const stale = store.findStale("widget", { name: "Trout Lure" });

  assert.ok(!stale.hasResults, "record has no stale results");
  assert.ok(!stale.results, "record results are absent");

  return stale.refresh().then(result => {
    assert.equal(
      result.get("firstObject.id"),
      123,
      "a `refresh()` method provides results for stale"
    );
  });
});

QUnit.test("update", assert => {
  const store = createStore();
  return store.update("widget", 123, { name: "hello" }).then(result => {
    assert.ok(result, "update returns a result");
  });
});

QUnit.test("update with a multi-word store type", assert => {
  const store = createStore();
  return store
    .update("cool-thing", 123, { name: "hello" })
    .then(result => {
      assert.ok(result, "update returns a result");
      assert.equal(result.payload.name, "hello", "record name is correct");
    });
});

QUnit.test("findAll", assert => {
  const store = createStore();
  return store.findAll("widget").then(findAllResult => {
    assert.equal(findAllResult.get("length"), 2, "result length is correct");

    const findByResult = findAllResult.findBy("id", 124);
    assert.ok(!findByResult.get("isNew"), "found record is not new");
    assert.equal(findByResult.get("name"), "Evil Repellant", "found record name is correct");
  });
});

QUnit.test("destroyRecord", assert => {
  const store = createStore();
  return store.find("widget", 123).then(findResult => {
    store.destroyRecord("widget", findResult).then(destroyResult => {
      assert.ok(destroyResult, "destroyRecord returns a result");
    });
  });
});

QUnit.test("destroyRecord when new", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { name: "hello" });
  store.destroyRecord("widget", widget).then(result => {
    assert.ok(result, "destroyRecord returns a result");
  });
});

QUnit.test("find embedded", assert => {
  const store = createStore();
  return store.find("fruit", 2).then(result => {
    assert.ok(result.get("farmer"), "result has the embedded object");

    const fruitColors = result.get("colors");
    assert.equal(fruitColors.length, 2);
    assert.equal(fruitColors[0].get("id"), 1);
    assert.equal(fruitColors[1].get("id"), 2);

    assert.ok(result.get("category"), "categories are found automatically");
  });
});

QUnit.test("meta types", assert => {
  const store = createStore();
  return store.find("barn", 1).then(result => {
    assert.equal(
      result.get("owner.name"),
      "Old MacDonald",
      "result has the embedded farmer"
    );
  });
});

QUnit.test("findAll embedded", assert => {
  const store = createStore();
  return store.findAll("fruit").then(result => {
    assert.equal(result.objectAt(0).get("farmer.name"), "Old MacDonald");
    assert.equal(
      result.objectAt(0).get("farmer"),
      result.objectAt(1).get("farmer"),
      "points at the same object"
    );
    assert.equal(
      result.get("extras.hello"),
      "world",
      "it can supply extra information"
    );

    const fruitColors = result.objectAt(0).get("colors");
    assert.equal(fruitColors.length, 2);
    assert.equal(fruitColors[0].get("id"), 1);
    assert.equal(fruitColors[1].get("id"), 2);

    assert.equal(result.objectAt(2).get("farmer.name"), "Luke Skywalker");
  });
});
