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

QUnit.test("find", async assert => {
  const store = createStore();

  const widget = await store.find("widget", 123);
  assert.equal(widget.get("name"), "Trout Lure");
  assert.equal(widget.get("id"), 123);
  assert.ok(!widget.get("isNew"), "found records are not new");
  assert.equal(widget.get("extras.hello"), "world", "extra attributes are set");

  // A second find by id returns the same object
  const widget2 = await store.find("widget", 123);
  assert.equal(widget, widget2);
  assert.equal(widget.get("extras.hello"), "world", "extra attributes are set");
});

QUnit.test("find with object id", async assert => {
  const store = createStore();
  const widget = await store.find("widget", { id: 123 });
  assert.equal(widget.get("firstObject.name"), "Trout Lure");
});

QUnit.test("find with query param", async assert => {
  const store = createStore();
  const widget = await store.find("widget", { name: "Trout Lure" });
  assert.equal(widget.get("firstObject.id"), 123);
});

QUnit.test("findStale with no stale results", async assert => {
  const store = createStore();
  const stale = store.findStale("widget", { name: "Trout Lure" });

  assert.ok(!stale.hasResults, "there are no stale results");
  assert.ok(!stale.results, "results are present");
  const widget = await stale.refresh();
  assert.equal(
    widget.get("firstObject.id"),
    123,
    "a `refresh()` method provides results for stale"
  );
});

QUnit.test("update", async assert => {
  const store = createStore();
  const result = await store.update("widget", 123, { name: "hello" });
  assert.ok(result);
});

QUnit.test("update with a multi world name", async assert => {
  const store = createStore();
  const result = await store.update("cool-thing", 123, { name: "hello" });
  assert.ok(result);
  assert.equal(result.payload.name, "hello");
});

QUnit.test("findAll", async assert => {
  const store = createStore();
  const result = await store.findAll("widget");
  assert.equal(result.get("length"), 2);

  const widget = result.findBy("id", 124);
  assert.ok(!widget.get("isNew"), "found records are not new");
  assert.equal(widget.get("name"), "Evil Repellant");
});

QUnit.test("destroyRecord", async assert => {
  const store = createStore();
  const widget = await store.find("widget", 123);

  assert.ok(await store.destroyRecord("widget", widget));
});

QUnit.test("destroyRecord when new", async assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { name: "hello" });

  assert.ok(await store.destroyRecord("widget", widget));
});

QUnit.test("find embedded", async assert => {
  const store = createStore();
  const fruit = await store.find("fruit", 1);
  assert.ok(fruit.get("farmer"), "it has the embedded object");

  const fruitCols = fruit.get("colors");
  assert.equal(fruitCols.length, 2);
  assert.equal(fruitCols[0].get("id"), 1);
  assert.equal(fruitCols[1].get("id"), 2);

  assert.ok(fruit.get("category"), "categories are found automatically");
});

QUnit.test("embedded records can be cleared", async assert => {
  const store = createStore();
  let fruit = await store.find("fruit", 4);
  fruit.set("farmer", { dummy: "object" });

  fruit = await store.find("fruit", 4);
  assert.ok(!fruit.get("farmer"));
});

QUnit.test("meta types", async assert => {
  const store = createStore();
  const barn = await store.find("barn", 1);
  assert.equal(
    barn.get("owner.name"),
    "Old MacDonald",
    "it has the embedded farmer"
  );
});

QUnit.test("findAll embedded", async assert => {
  const store = createStore();
  const fruits = await store.findAll("fruit");
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

QUnit.test("custom primaryKey", async assert => {
  const store = createStore();
  const cats = await store.findAll("cat");
  assert.equal(cats.objectAt(0).name, "souna");
});
