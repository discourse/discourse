import { module, test } from "qunit";
import RestAdapter from "discourse/adapters/rest";
import RestModel from "discourse/models/rest";
import createStore from "discourse/tests/helpers/create-store";
import sinon from "sinon";

module("Unit | Model | rest-model", function () {
  test("munging", function (assert) {
    const store = createStore();
    const Grape = RestModel.extend();
    Grape.reopenClass({
      munge: function (json) {
        json.inverse = 1 - json.percent;
        return json;
      },
    });

    let g = Grape.create({ store, percent: 0.4 });
    assert.equal(g.get("inverse"), 0.6, "it runs `munge` on `create`");
  });

  test("update", async function (assert) {
    const store = createStore();
    const widget = await store.find("widget", 123);
    assert.equal(widget.get("name"), "Trout Lure");
    assert.ok(!widget.get("isSaving"), "it is not saving");

    const spyBeforeUpdate = sinon.spy(widget, "beforeUpdate");
    const spyAfterUpdate = sinon.spy(widget, "afterUpdate");
    const promise = widget.update({ name: "new name" });
    assert.ok(widget.get("isSaving"), "it is saving");
    assert.ok(spyBeforeUpdate.calledOn(widget));

    const result = await promise;
    assert.ok(spyAfterUpdate.calledOn(widget));
    assert.ok(!widget.get("isSaving"), "it is no longer saving");
    assert.equal(widget.get("name"), "new name");

    assert.ok(result.target, "it has a reference to the record");
    assert.equal(result.target.name, widget.get("name"));
  });

  test("updating simultaneously", async function (assert) {
    assert.expect(2);

    const store = createStore();
    const widget = await store.find("widget", 123);

    const firstPromise = widget.update({ name: "new name" });
    const secondPromise = widget.update({ name: "new name" });

    firstPromise.then(function () {
      assert.ok(true, "the first promise succeeds");
    });

    secondPromise.catch(function () {
      assert.ok(true, "the second promise fails");
    });
  });

  test("save new", async function (assert) {
    const store = createStore();
    const widget = store.createRecord("widget");

    assert.ok(widget.get("isNew"), "it is a new record");
    assert.ok(!widget.get("isCreated"), "it is not created");
    assert.ok(!widget.get("isSaving"), "it is not saving");

    const spyBeforeCreate = sinon.spy(widget, "beforeCreate");
    const spyAfterCreate = sinon.spy(widget, "afterCreate");
    const promise = widget.save({ name: "Evil Widget" });
    assert.ok(widget.get("isSaving"), "it is not saving");
    assert.ok(spyBeforeCreate.calledOn(widget));

    const result = await promise;
    assert.ok(spyAfterCreate.calledOn(widget));
    assert.ok(!widget.get("isSaving"), "it is no longer saving");
    assert.ok(widget.get("id"), "it has an id");
    assert.ok(widget.get("name"), "Evil Widget");
    assert.ok(widget.get("isCreated"), "it is created");
    assert.ok(!widget.get("isNew"), "it is no longer new");

    assert.ok(result.target, "it has a reference to the record");
    assert.equal(result.target.name, widget.get("name"));
  });

  test("creating simultaneously", function (assert) {
    assert.expect(2);

    const store = createStore();
    const widget = store.createRecord("widget");

    const firstPromise = widget.save({ name: "Evil Widget" });
    const secondPromise = widget.save({ name: "Evil Widget" });
    firstPromise.then(function () {
      assert.ok(true, "the first promise succeeds");
    });

    secondPromise.catch(function () {
      assert.ok(true, "the second promise fails");
    });
  });

  test("destroyRecord", async function (assert) {
    const store = createStore();
    const widget = await store.find("widget", 123);

    assert.ok(await widget.destroyRecord());
  });

  test("custom api name", async function (assert) {
    const store = createStore((type) => {
      if (type === "adapter:my-widget") {
        return RestAdapter.extend({
          // An adapter like this is used when the server-side key/url
          // do not match the name of the es6 class
          apiNameFor() {
            return "widget";
          },
        }).create();
      }
    });

    // The pretenders only respond to requests for `widget`
    // If these basic tests pass, the name override worked correctly

    //Create
    const widget = store.createRecord("my-widget");
    await widget.save({ name: "Evil Widget" });
    assert.equal(widget.id, 100, "it saved a new record successfully");
    assert.equal(widget.get("name"), "Evil Widget");

    // Update
    await widget.update({ name: "new name" });
    assert.equal(widget.get("name"), "new name");

    // Destroy
    await widget.destroyRecord();

    // Lookup
    const foundWidget = await store.find("my-widget", 123);
    assert.equal(foundWidget.name, "Trout Lure");
  });
});
