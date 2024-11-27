import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import RestAdapter from "discourse/adapters/rest";
import RestModel from "discourse/models/rest";

module("Unit | Model | rest-model", function (hooks) {
  setupTest(hooks);

  test("munging", function (assert) {
    const store = getOwner(this).lookup("service:store");
    class Grape extends RestModel {}
    Grape.reopenClass({
      munge: function (json) {
        json.inverse = 1 - json.percent;
        return json;
      },
    });

    getOwner(this).register("model:grape", Grape);
    const g = store.createRecord("grape", { store, percent: 0.4 });
    assert.strictEqual(g.inverse, 0.6, "runs `munge` on `create`");
  });

  test("update", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = await store.find("widget", 123);
    assert.strictEqual(widget.name, "Trout Lure");
    assert.false(widget.isSaving, "is not saving");

    const spyBeforeUpdate = sinon.spy(widget, "beforeUpdate");
    const spyAfterUpdate = sinon.spy(widget, "afterUpdate");
    const promise = widget.update({ name: "new name" });
    assert.true(widget.isSaving, "is saving");
    assert.true(spyBeforeUpdate.calledOn(widget));

    const result = await promise;
    assert.true(spyAfterUpdate.calledOn(widget));
    assert.false(widget.isSaving, "is no longer saving");
    assert.strictEqual(widget.name, "new name");

    assert.notStrictEqual(
      result.target,
      undefined,
      "has a reference to the record"
    );
    assert.strictEqual(result.target.name, widget.name);
  });

  test("updating simultaneously", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = await store.find("widget", 123);

    const firstPromise = widget.update({ name: "new name" });
    const secondPromise = widget.update({ name: "new name" });

    firstPromise.then(() => assert.true(true, "the first promise succeeds"));
    secondPromise.catch(() => assert.true(true, "the second promise fails"));

    await Promise.allSettled([firstPromise, secondPromise]);
  });

  test("save new", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget");

    assert.true(widget.isNew, "is a new record");
    assert.false(widget.isCreated, "is not created");
    assert.false(widget.isSaving, "is not saving");

    const spyBeforeCreate = sinon.spy(widget, "beforeCreate");
    const spyAfterCreate = sinon.spy(widget, "afterCreate");
    const promise = widget.save({ name: "Evil Widget" });
    assert.true(widget.isSaving, "is not saving");
    assert.true(spyBeforeCreate.calledOn(widget));

    const result = await promise;
    assert.true(spyAfterCreate.calledOn(widget));
    assert.false(widget.isSaving, "is no longer saving");
    assert.notStrictEqual(widget.id, undefined, "has an id");
    assert.strictEqual(widget.name, "Evil Widget");
    assert.true(widget.isCreated, " is created");
    assert.false(widget.isNew, "is no longer new");

    assert.notStrictEqual(
      result.target,
      undefined,
      "has a reference to the record"
    );
    assert.strictEqual(result.target.name, widget.name);
  });

  test("creating simultaneously", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget");

    const firstPromise = widget.save({ name: "Evil Widget" });
    const secondPromise = widget.save({ name: "Evil Widget" });

    firstPromise.then(() => assert.true(true, "the first promise succeeds"));
    secondPromise.catch(() => assert.true(true, "the second promise fails"));

    await Promise.allSettled([firstPromise, secondPromise]);
  });

  test("destroyRecord", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = await store.find("widget", 123);

    assert.deepEqual(await widget.destroyRecord(), {
      success: true,
    });
  });

  test("custom api name", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    getOwner(this).register(
      "adapter:my-widget",
      class extends RestAdapter {
        // An adapter like this is used when the server-side key/url
        // do not match the name of the es6 class
        apiNameFor() {
          return "widget";
        }
      }
    );

    // The pretenders only respond to requests for `widget`
    // If these basic tests pass, the name override worked correctly

    // Create
    const widget = store.createRecord("my-widget");
    await widget.save({ name: "Evil Widget" });
    assert.strictEqual(widget.id, 100, "saved a new record successfully");
    assert.strictEqual(widget.name, "Evil Widget");

    // Update
    await widget.update({ name: "new name" });
    assert.strictEqual(widget.name, "new name");

    // Destroy
    await widget.destroyRecord();

    // Lookup
    const foundWidget = await store.find("my-widget", 123);
    assert.strictEqual(foundWidget.name, "Trout Lure");
  });
});
