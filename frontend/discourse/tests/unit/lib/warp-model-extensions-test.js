import { addObserver } from "@ember/object/observers";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { rollbackAllPrepends } from "discourse/lib/class-prepend";
import {
  modelNameFor,
  resetModelExtensions,
} from "discourse/lib/model-extensions";
import { withPluginApi } from "discourse/lib/plugin-api";
import { isTrackedArray } from "discourse/lib/tracked-tools";
import Badge from "discourse/models/badge";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";

// Mirrors `model-extensions-test.js`, but exercises the extension APIs against a
// WarpDrive-backed model (`badge`) rather than a `RestModel`.
module("Unit | Lib | model-extensions (WarpDrive)", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
  });

  hooks.afterEach(function () {
    rollbackAllPrepends();
    resetModelExtensions();
  });

  test("modelNameFor resolves via `static type` without stamping", function (assert) {
    const badge = this.store.createRecord("badge", { name: "a" });
    assert.strictEqual(modelNameFor(badge), "badge");
  });

  test("addModelField uses the default until a server value overrides it", function (assert) {
    withPluginApi((api) =>
      api.addModelField("badge", "rank", { defaultValue: 5 })
    );

    const record = this.store.createRecord("badge", { name: "a" });
    assert.strictEqual(record.rank, 5, "falls back to the default");

    record.rank = 9;
    assert.strictEqual(record.rank, 9, "the field is writable and tracked");

    const fromServer = this.store.createRecord("badge", { name: "b", rank: 7 });
    assert.strictEqual(fromServer.rank, 7, "a server value wins");
  });

  test("addModelField type array gives per-instance tracked arrays", function (assert) {
    withPluginApi((api) =>
      api.addModelField("badge", "extras", { type: "array", defaultValue: [] })
    );

    const a = this.store.createRecord("badge", { name: "a" });
    const b = this.store.createRecord("badge", { name: "b" });

    assert.true(isTrackedArray(a.extras), "the default is a tracked array");

    a.extras.push("x");
    assert.deepEqual([...a.extras], ["x"]);
    assert.deepEqual([...b.extras], [], "each record gets its own array");

    a.extras = ["y", "z"];
    assert.true(isTrackedArray(a.extras), "an assigned plain array is coerced");
    assert.deepEqual([...a.extras], ["y", "z"]);
  });

  test("addModelField type array coerces a server-provided array", function (assert) {
    withPluginApi((api) =>
      api.addModelField("badge", "extras", { type: "array" })
    );

    const record = this.store.createRecord("badge", {
      name: "a",
      extras: ["p", "q"],
    });

    assert.true(isTrackedArray(record.extras));
    assert.deepEqual([...record.extras], ["p", "q"]);
  });

  test("addModelField type object gives a per-instance tracked object", function (assert) {
    withPluginApi((api) =>
      api.addModelField("badge", "bag", { type: "object" })
    );

    const a = this.store.createRecord("badge", { name: "a" });
    const b = this.store.createRecord("badge", { name: "b" });

    assert.notStrictEqual(a.bag, b.bag, "each record gets its own object");
    a.bag.x = 1;
    assert.strictEqual(b.bag.x, undefined, "mutations do not leak");
  });

  test("addModelField type set gives a per-instance tracked set", function (assert) {
    withPluginApi((api) => api.addModelField("badge", "seen", { type: "set" }));

    const a = this.store.createRecord("badge", { name: "a" });
    const b = this.store.createRecord("badge", { name: "b" });

    a.seen.add("x");
    assert.true(a.seen.has("x"));
    assert.false(b.seen.has("x"), "mutations do not leak");
  });

  test("addModelField function defaultValue runs per instance", function (assert) {
    withPluginApi((api) =>
      api.addModelField("badge", "bag", { defaultValue: () => ({}) })
    );

    const a = this.store.createRecord("badge", { name: "a" });
    const b = this.store.createRecord("badge", { name: "b" });

    assert.notStrictEqual(a.bag, b.bag, "each record gets its own object");
    a.bag.x = 1;
    assert.strictEqual(b.bag.x, undefined, "mutations do not leak");
  });

  test("addModelField resettable resets to the initializer when it changes", function (assert) {
    withPluginApi((api) =>
      api.addModelField("badge", "derivedName", {
        resettable: true,
        defaultValue() {
          return this.name;
        },
      })
    );

    const record = this.store.createRecord("badge", { name: "a" });
    assert.strictEqual(record.derivedName, "a", "derives from the instance");

    record.derivedName = "manual";
    assert.strictEqual(
      record.derivedName,
      "manual",
      "a manual set sticks while the derived value is unchanged"
    );

    record.name = "b";
    assert.strictEqual(
      record.derivedName,
      "b",
      "resets to the new derived value, discarding the manual set"
    );
  });

  test("addModelSaveProperty includes the property in the save payload", async function (assert) {
    withPluginApi((api) => {
      api.addModelField("badge", "rank", { defaultValue: 0 });
      api.addModelSaveProperty("badge", "rank");
    });

    const record = this.store.createRecord("badge", {
      id: 42,
      name: "a",
      rank: 7,
    });

    pretender.put("/admin/badges/42", (request) => {
      const params = parsePostData(request.requestBody);
      assert.strictEqual(params.rank, "7", "merged into the payload");
      assert.step("called API");
      return response({});
    });

    await record.save({ name: "a" });
    assert.verifySteps(["called API"]);
  });

  test("addModelSaveProperty accepts a value function", async function (assert) {
    withPluginApi((api) =>
      api.addModelSaveProperty("badge", "derived_name", function () {
        return this.name.toUpperCase();
      })
    );

    const record = this.store.createRecord("badge", { id: 43, name: "abc" });

    pretender.put("/admin/badges/43", (request) => {
      const params = parsePostData(request.requestBody);
      assert.strictEqual(params.derived_name, "ABC", "computed value merged");
      assert.step("called API");
      return response({});
    });

    await record.save({ name: "abc" });
    assert.verifySteps(["called API"]);
  });

  test("addModelCallback init fires after the create args are applied", function (assert) {
    const seen = [];
    withPluginApi((api) =>
      api.addModelCallback("badge", "init", function () {
        seen.push(this.name);
      })
    );

    this.store.createRecord("badge", { name: "a" });
    assert.deepEqual(seen, ["a"], "runs once, with the assigned args visible");
  });

  test("addModelCallback afterCreate fires on create", async function (assert) {
    withPluginApi((api) =>
      api.addModelCallback("badge", "afterCreate", () => assert.step("create"))
    );

    const record = this.store.createRecord("badge", { name: "a" });

    pretender.post("/admin/badges", () => {
      assert.step("api");
      return response({});
    });

    await record.save();
    assert.verifySteps(
      ["api", "create"],
      "afterCreate fires after the request"
    );
  });

  test("addModelCallback afterUpdate fires on update", async function (assert) {
    withPluginApi((api) =>
      api.addModelCallback("badge", "afterUpdate", () => assert.step("update"))
    );

    const record = this.store.createRecord("badge", { id: 88, name: "a" });

    pretender.put("/admin/badges/88", () => {
      assert.step("api");
      return response({});
    });

    await record.save({ name: "b" });
    assert.verifySteps(
      ["api", "update"],
      "afterUpdate fires after the request"
    );
  });

  test("addModelCallback fires destroy callbacks around the request", async function (assert) {
    withPluginApi((api) => {
      api.addModelCallback("badge", "beforeDestroy", () =>
        assert.step("before")
      );
      api.addModelCallback("badge", "afterDestroy", () => assert.step("after"));
    });

    const record = this.store.createRecord("badge", { id: 5, name: "a" });

    pretender.delete("/admin/badges/5", () => {
      assert.step("api");
      return response({});
    });

    await record.destroy();
    assert.verifySteps(["before", "api", "after"]);
  });

  test("addModelGetter adds a getter-only derived property", function (assert) {
    withPluginApi((api) =>
      api.addModelGetter("badge", "upperName", function () {
        return this.name?.toUpperCase();
      })
    );

    const record = this.store.createRecord("badge", { name: "abc" });
    assert.strictEqual(record.upperName, "ABC");
  });

  test("addModelSetter adds a setter-only accessor", function (assert) {
    withPluginApi((api) =>
      api.addModelSetter("badge", "shout", function (value) {
        this.name = value.toLowerCase();
      })
    );

    const record = this.store.createRecord("badge", { name: "x" });
    record.shout = "HELLO";
    assert.strictEqual(record.name, "hello");
  });

  test("addModelAccessor adds a property with a getter and a setter", function (assert) {
    withPluginApi((api) =>
      api.addModelAccessor("badge", "upperName", {
        get() {
          return this.name?.toUpperCase();
        },
        set(value) {
          this.name = value.toLowerCase();
        },
      })
    );

    const record = this.store.createRecord("badge", { name: "abc" });
    assert.strictEqual(record.upperName, "ABC", "the getter derives a value");

    record.upperName = "XYZ";
    assert.strictEqual(record.name, "xyz", "the setter runs");
    assert.strictEqual(record.upperName, "XYZ");
  });

  test("addModelMethod adds an instance method", function (assert) {
    withPluginApi((api) =>
      api.addModelMethod("badge", "greet", function () {
        return `${this.name}!`;
      })
    );

    const record = this.store.createRecord("badge", { name: "hi" });
    assert.strictEqual(record.greet(), "hi!");
  });

  test("addModelGetter is observable by classic observers (dependentKeyCompat)", async function (assert) {
    withPluginApi((api) => {
      api.addModelField("badge", "count", { defaultValue: 1 });
      api.addModelGetter("badge", "doubled", function () {
        return this.count * 2;
      });
    });

    const record = this.store.createRecord("badge", { name: "a" });
    assert.strictEqual(record.doubled, 2, "derives from the tracked field");

    // eslint-disable-next-line ember/no-observers -- verifies classic-observer interop
    addObserver(record, "doubled", () => assert.step("changed"));
    record.count = 5;
    await settled();

    assert.verifySteps(["changed"], "a classic observer fires on change");
    assert.strictEqual(record.doubled, 10);
  });

  test("addModelField applies to records loaded from the server", async function (assert) {
    withPluginApi((api) =>
      api.addModelField("badge", "rank", { defaultValue: 5 })
    );

    pretender.get("/badges.json", () =>
      response({
        badges: [{ id: 1, name: "a", badge_type_id: 1 }],
        badge_types: [{ id: 1, name: "Gold" }],
        badge_groupings: [],
      })
    );

    const badges = await Badge.findAll();
    assert.strictEqual(badges.length, 1, "loads the badge");
    assert.strictEqual(
      badges[0].rank,
      5,
      "reads the registered field off a cached record"
    );
  });
});
