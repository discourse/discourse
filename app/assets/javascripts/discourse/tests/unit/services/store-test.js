import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, {
  fixturesByUrl,
  response,
} from "discourse/tests/helpers/create-pretender";

module("Unit | Service | store", function (hooks) {
  setupTest(hooks);

  test("createRecord", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget", { id: 111, name: "hello" });

    assert.false(widget.isNew, "it is not a new record");
    assert.strictEqual(widget.name, "hello");
    assert.strictEqual(widget.id, 111);
  });

  test("createRecord without an `id`", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget", { name: "hello" });

    assert.true(widget.isNew, "it is a new record");
    assert.strictEqual(widget.id, undefined, "there is no id");
  });

  test("createRecord doesn't modify the input `id` field", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget", { id: 1, name: "hello" });

    const obj = { id: 1, name: "something" };

    const other = store.createRecord("widget", obj);
    assert.strictEqual(widget, other, "returns the same record");
    assert.strictEqual(widget.name, "something", "it updates the properties");
    assert.strictEqual(obj.id, 1, "it does not remove the id from the input");
  });

  test("createRecord without attributes", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget");

    assert.strictEqual(widget.id, undefined, "there is no id");
    assert.true(widget.isNew, "it is a new record");
  });

  test("createRecord with a record as attributes returns that record from the map", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget", { id: 33 });
    const secondWidget = store.createRecord("widget", { id: 33 });

    assert.strictEqual(widget, secondWidget, "they should be the same");
  });

  test("find", async function (assert) {
    const store = getOwner(this).lookup("service:store");

    const widget = await store.find("widget", 123);
    assert.strictEqual(widget.name, "Trout Lure");
    assert.strictEqual(widget.id, 123);
    assert.false(widget.isNew, "found records are not new");
    assert.strictEqual(
      widget.extras.hello,
      "world",
      "extra attributes are set"
    );

    // A second find by id returns the same object
    const widget2 = await store.find("widget", 123);
    assert.strictEqual(widget, widget2);
    assert.strictEqual(
      widget.extras.hello,
      "world",
      "extra attributes are set"
    );
  });

  test("find with object id", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = await store.find("widget", { id: 123 });
    assert.strictEqual(widget.firstObject.name, "Trout Lure");
  });

  test("find with query param", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = await store.find("widget", { name: "Trout Lure" });
    assert.strictEqual(widget.firstObject.id, 123);
  });

  test("findStale with no stale results", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const stale = store.findStale("widget", { name: "Trout Lure" });

    assert.false(stale.hasResults, "there are no stale results");
    assert.strictEqual(stale.results, undefined, "results are not present");

    const widget = await stale.refresh();
    assert.strictEqual(
      widget.firstObject.id,
      123,
      "a `refresh()` method provides results for stale"
    );
  });

  test("rehydrating stale results with implicit injections", async function (assert) {
    pretender.get("/notifications", ({ queryParams }) => {
      if (queryParams.slug === "souna") {
        return response({
          notifications: [
            {
              id: 915,
              slug: "souna",
            },
          ],
        });
      }
    });

    const store = getOwner(this).lookup("service:store");
    const notifications = await store.find("notification", { slug: "souna" });
    assert.strictEqual(notifications.content[0].slug, "souna");

    const stale = store.findStale("notification", { slug: "souna" });
    assert.true(stale.hasResults);
    assert.strictEqual(stale.results.content[0].slug, "souna");

    const refreshed = await stale.refresh();
    assert.strictEqual(refreshed.content[0].slug, "souna");
  });

  test("update", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const result = await store.update("widget", 123, { name: "hello" });
    assert.strictEqual(result.payload.name, "hello");
  });

  test("update with a multi world name", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const result = await store.update("cool-thing", 123, { name: "hello" });
    assert.strictEqual(result.payload.name, "hello");
  });

  test("findAll", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const result = await store.findAll("widget");
    assert.strictEqual(result.length, 2);

    const widget = result.findBy("id", 124);
    assert.false(widget.isNew, "found records are not new");
    assert.strictEqual(widget.name, "Evil Repellant");
  });

  test("destroyRecord", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = await store.find("widget", 123);

    const result = await store.destroyRecord("widget", widget);
    assert.deepEqual(result, { success: true });
  });

  test("destroyRecord when new", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const widget = store.createRecord("widget", { name: "hello" });

    assert.true(await store.destroyRecord("widget", widget));
  });

  test("find embedded", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const fruit = await store.find("fruit", 1);

    assert.propContains(
      fruit.farmer,
      { id: 1, name: "Old MacDonald" },
      "it has the embedded object"
    );
    assert.strictEqual(fruit.colors.length, 2);
    assert.strictEqual(fruit.colors[0].id, 1);
    assert.strictEqual(fruit.colors[1].id, 2);
  });

  test("embedded records can be cleared", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    let fruit = await store.find("fruit", 4);
    fruit.set("farmer", { dummy: "object" });

    fruit = await store.find("fruit", 4);
    assert.strictEqual(fruit.farmer, null);
  });

  test("meta types", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const barn = await store.find("barn", 1);
    assert.strictEqual(
      barn.owner.name,
      "Old MacDonald",
      "it has the embedded farmer"
    );
  });

  test("findAll embedded", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const fruits = await store.findAll("fruit");
    assert.strictEqual(fruits.objectAt(0).farmer.name, "Old MacDonald");
    assert.strictEqual(
      fruits.objectAt(0).farmer,
      fruits.objectAt(1).farmer,
      "points at the same object"
    );
    assert.strictEqual(
      fruits.extras.hello,
      "world",
      "it can supply extra information"
    );

    const fruitCols = fruits.objectAt(0).colors;
    assert.strictEqual(fruitCols.length, 2);
    assert.strictEqual(fruitCols[0].id, 1);
    assert.strictEqual(fruitCols[1].id, 2);

    assert.strictEqual(fruits.objectAt(2).farmer.name, "Luke Skywalker");
  });

  test("custom primaryKey", async function (assert) {
    pretender.get("/users", () => {
      return response({
        users: [
          {
            id: 915,
            username: "souna",
          },
        ],
      });
    });

    const store = getOwner(this).lookup("service:store");
    const users = await store.findAll("user");
    assert.strictEqual(users.objectAt(0).username, "souna");
  });

  test("findFiltered", async function (assert) {
    pretender.get("/topics/created-by/trout.json", ({ queryParams }) => {
      assert.deepEqual(queryParams, {
        order: "latest",
        tags: ["dev", "bug"],
      });
      return response(fixturesByUrl["/c/bug/1/l/latest.json"]);
    });

    const store = getOwner(this).lookup("service:store");
    const result = await store.findFiltered("topicList", {
      filter: "topics/created-by/trout",
      params: {
        order: "latest",
        tags: ["dev", "bug"],
      },
    });

    assert.true(result.loaded);
    assert.true("topic_list" in result);
    assert.true(Array.isArray(result.topics));
    assert.strictEqual(result.filter, "topics/created-by/trout");
  });

  test("Spec incompliant embedded record name", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    const fruit = await store.find("fruit", 4);

    assert.propContains(
      fruit.other_fruit_ids,
      { apple: 1, banana: 2 },
      "embedded record remains unhydrated"
    );
  });
});
