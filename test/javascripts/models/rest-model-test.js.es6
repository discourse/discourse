QUnit.module("rest-model");

import createStore from "helpers/create-store";
import RestModel from "discourse/models/rest";

QUnit.test("munging", assert => {
  const store = createStore();
  const Grape = RestModel.extend();
  Grape.reopenClass({
    munge(json) {
      json.inverse = 1 - json.percent;
      return json;
    }
  });

  const g = Grape.create({ store, percent: 0.4 });
  assert.equal(g.get("inverse"), 0.6, "it runs `munge` on `create`");
});

QUnit.test("update", assert => {
  const store = createStore();
  return store.find("widget", 123).then(widget => {
    assert.equal(widget.get("name"), "Trout Lure", "name property is set correctly");
    assert.ok(!widget.get("isSaving"), "record is not saving");

    const promise = widget.update({ name: "new name" });
    assert.ok(widget.get("isSaving"), "record is now saving (`update` was called)");

    promise.then(result => {
      console.log(result);
      assert.ok(
        !widget.get("isSaving"),
        "record is no longer saving (record was sent to the server)"
      );
      assert.equal(widget.get("name"), "new name", "name property was updated");

      assert.ok(result.hasOwnProperty("target"), "the result has a reference to the record");
      assert.equal(
        result.payload.name,
        widget.get("name"),
        "both client-side record and result were updated"
      );
    });
  });
});

QUnit.test("updating simultaneously", assert => {
  assert.expect(2);

  const store = createStore();
  return store.find("widget", 123).then(widget => {
    const firstPromise = widget.update({ name: "new name" });
    const secondPromise = widget.update({ name: "new name" });

    firstPromise.then(() => {
      assert.ok(true, "the first promise succeeeded");
    });

    secondPromise.catch(() => {
      assert.ok(true, "the second promise failed");
    });
  });
});

QUnit.test("save new record", assert => {
  const store = createStore();
  const widget = store.createRecord("widget");

  assert.ok(widget.get("isNew"), "record is new");
  assert.ok(!widget.get("isCreated"), "record is not created");
  assert.ok(!widget.get("isSaving"), "record is not saving");

  const promise = widget.save({ name: "Evil Widget" });
  assert.ok(widget.get("isSaving"), "record is not saving");

  return promise.then(result => {
    assert.ok(!widget.get("isNew"), "record is no longer new");
    assert.ok(widget.get("isCreated"), "record is created");
    assert.ok(!widget.get("isSaving"), "record is no longer saving");
    assert.ok(widget.get("id") !== undefined, "record has an id");
    assert.equal(widget.get("name"), "Evil Widget", "name property was updated");

    assert.ok(result.hasOwnProperty("target"), "record has a reference to the record");
    assert.equal(
      result.payload.name,
      widget.get("name"),
      "both client-side record and result were updated"
    );
  });
});

QUnit.test("save record with ID", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { id: 456 });

  // Records with an `id` property are not treated as new.
  assert.ok(!widget.get("isNew"), "record is not new");
  assert.ok(widget.get("isCreated"), "record is created");
  assert.ok(widget.get("id") !== undefined, "record has an id");
  assert.equal(widget.get("id"), 456, "record ID is correct");

  const promise = widget.save({ name: "Friendly ID" });

  return promise.then(result => {
    assert.ok(result.hasOwnProperty("target"), "record has a reference to the record");
    assert.equal(
      result.payload.name,
      widget.get("name"),
      "both client-side record and result were updated"
    );
  });
});

QUnit.test("save record with ID 0", assert => {
  const store = createStore();
  const widget = store.createRecord("widget", { id: 0 });

  assert.ok(!widget.get("isNew"), "record is not new");
  assert.ok(widget.get("isCreated"), "record is created");
  assert.ok(widget.get("id") !== undefined, "record has an id");
  assert.equal(widget.get("id"), 0, "record ID is correct");

  const promise = widget.save({ name: "Evil ID" });

  return promise.then(result => {
    assert.ok(result.hasOwnProperty("target"), "record has a reference to the record");
    assert.equal(
      result.payload.name,
      widget.get("name"),
      "both client-side record and result were updated"
    );

    assert.deepEqual(
      result.target,
      widget,
      "Client-side record and `result.target` are identical"
    );
  });
});

QUnit.test("creating simultaneously", assert => {
  assert.expect(2);

  const store = createStore();
  const widget = store.createRecord("widget");

  const firstPromise = widget.save({ name: "Evil Widget" });
  const secondPromise = widget.save({ name: "Evil Widget" });

  firstPromise.then(() => {
    assert.ok(true, "the first promise succeeeded");
  });

  secondPromise.catch(() => {
    assert.ok(true, "the second promise failed");
  });
});

QUnit.test("destroyRecord", assert => {
  const store = createStore();
  return store.find("widget", 123).then(widget => {
    widget.destroyRecord().then(result => {
      assert.ok(result, "destroyRecord returns a result");
    });
  });
});
