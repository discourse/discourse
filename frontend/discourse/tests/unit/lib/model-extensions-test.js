import { addObserver } from "@ember/object/observers";
import { getOwner } from "@ember/owner";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import RestAdapter from "discourse/adapters/rest";
import { rollbackAllPrepends } from "discourse/lib/class-prepend";
import {
  applyModelCallbacks,
  modelFieldNames,
  registerModelCallback,
  registerModelField,
  resetModelExtensions,
} from "discourse/lib/model-extensions";
import { withPluginApi } from "discourse/lib/plugin-api";
import { isTrackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";

let capturedCreateProps;
let capturedUpdateProps;

class TestExtensionModel extends RestModel {
  createProperties() {
    return { name: this.name };
  }

  updateProperties() {
    return { name: this.name };
  }
}

class TestExtensionAdapter extends RestAdapter {
  createRecord(store, type, props) {
    capturedCreateProps = props;
    return Promise.resolve({ payload: { id: 1, ...props } });
  }

  update(store, type, id, props) {
    capturedUpdateProps = props;
    return Promise.resolve({ payload: { id, ...props } });
  }
}

module("Unit | Lib | model-extensions", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    capturedCreateProps = undefined;
    capturedUpdateProps = undefined;

    const owner = getOwner(this);
    owner.register("model:test-extension-model", TestExtensionModel);
    owner.register("adapter:test-extension-model", TestExtensionAdapter);
    this.store = owner.lookup("service:store");
  });

  hooks.afterEach(function () {
    rollbackAllPrepends();
    resetModelExtensions();
  });

  test("addModelField uses the default until a server value overrides it", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "rank", { defaultValue: 5 })
    );

    const record = this.store.createRecord("test-extension-model", {
      name: "a",
    });
    assert.strictEqual(record.rank, 5, "falls back to the default");

    record.rank = 9;
    assert.strictEqual(record.rank, 9, "the field is writable and tracked");

    const fromServer = this.store.createRecord("test-extension-model", {
      name: "b",
      rank: 7,
    });
    assert.strictEqual(fromServer.rank, 7, "a server value wins");
  });

  test("addModelField type array gives per-instance tracked arrays", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "tags", {
        type: "array",
        defaultValue: [],
      })
    );

    const a = this.store.createRecord("test-extension-model", { name: "a" });
    const b = this.store.createRecord("test-extension-model", { name: "b" });

    assert.true(isTrackedArray(a.tags), "the default is a tracked array");

    a.tags.push("x");
    assert.deepEqual([...a.tags], ["x"]);
    assert.deepEqual([...b.tags], [], "each record gets its own array");

    a.tags = ["y", "z"];
    assert.true(isTrackedArray(a.tags), "an assigned plain array is coerced");
    assert.deepEqual([...a.tags], ["y", "z"]);
  });

  test("addModelField type array coerces a server-provided array", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "tags", { type: "array" })
    );

    const record = this.store.createRecord("test-extension-model", {
      name: "a",
      tags: ["p", "q"],
    });

    assert.true(isTrackedArray(record.tags));
    assert.deepEqual([...record.tags], ["p", "q"]);
  });

  test("addModelField type object gives a per-instance tracked object", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "bag", { type: "object" })
    );

    const a = this.store.createRecord("test-extension-model", { name: "a" });
    const b = this.store.createRecord("test-extension-model", { name: "b" });

    assert.notStrictEqual(a.bag, b.bag, "each record gets its own object");
    a.bag.x = 1;
    assert.strictEqual(b.bag.x, undefined, "mutations do not leak");
  });

  test("addModelField type set gives a per-instance tracked set", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "seen", { type: "set" })
    );

    const a = this.store.createRecord("test-extension-model", { name: "a" });
    const b = this.store.createRecord("test-extension-model", { name: "b" });

    a.seen.add("x");
    assert.true(a.seen.has("x"));
    assert.false(b.seen.has("x"), "mutations do not leak");
  });

  test("addModelField rejects an unknown type", function (assert) {
    assert.throws(
      () =>
        withPluginApi((api) =>
          api.addModelField("test-extension-model", "bad", { type: "bogus" })
        ),
      /Unknown model field type/
    );
  });

  test("addModelField function defaultValue runs per instance", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "bag", {
        defaultValue: () => ({}),
      })
    );

    const a = this.store.createRecord("test-extension-model", { name: "a" });
    const b = this.store.createRecord("test-extension-model", { name: "b" });

    assert.notStrictEqual(a.bag, b.bag, "each record gets its own object");
    a.bag.x = 1;
    assert.strictEqual(b.bag.x, undefined, "mutations do not leak");
  });

  test("addModelField function defaultValue is a fallback the server payload overrides", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "rank", {
        defaultValue: () => 5,
      })
    );

    const withoutValue = this.store.createRecord("test-extension-model", {
      name: "a",
    });
    assert.strictEqual(withoutValue.rank, 5, "used when the server omits it");

    const withValue = this.store.createRecord("test-extension-model", {
      name: "b",
      rank: 9,
    });
    assert.strictEqual(withValue.rank, 9, "a server value wins");
  });

  test("addModelField resettable resets to the initializer when it changes", function (assert) {
    withPluginApi((api) =>
      api.addModelField("test-extension-model", "derivedName", {
        resettable: true,
        defaultValue() {
          return this.name;
        },
      })
    );

    const record = this.store.createRecord("test-extension-model", {
      name: "a",
    });
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

  test("addModelField resettable requires a function defaultValue", function (assert) {
    assert.throws(
      () =>
        withPluginApi((api) =>
          api.addModelField("test-extension-model", "bad", {
            resettable: true,
            defaultValue: 5,
          })
        ),
      /`resettable` requires `defaultValue` to be a function/
    );
  });

  test("addModelSetter adds a setter-only accessor", function (assert) {
    withPluginApi((api) =>
      api.addModelSetter("test-extension-model", "shout", function (value) {
        this.name = value.toLowerCase();
      })
    );

    const record = this.store.createRecord("test-extension-model", {
      name: "x",
    });
    record.shout = "HELLO";
    assert.strictEqual(record.name, "hello");
  });

  test("addModelAccessor adds a property with a getter and a setter", function (assert) {
    withPluginApi((api) =>
      api.addModelAccessor("test-extension-model", "upperName", {
        get() {
          return this.name?.toUpperCase();
        },
        set(value) {
          this.name = value.toLowerCase();
        },
      })
    );

    const record = this.store.createRecord("test-extension-model", {
      name: "abc",
    });
    assert.strictEqual(record.upperName, "ABC", "the getter derives a value");

    record.upperName = "XYZ";
    assert.strictEqual(record.name, "xyz", "the setter runs");
    assert.strictEqual(record.upperName, "XYZ");
  });

  test("addModelGetter adds a getter-only derived property", function (assert) {
    withPluginApi((api) =>
      api.addModelGetter("test-extension-model", "upperName", function () {
        return this.name?.toUpperCase();
      })
    );

    const record = this.store.createRecord("test-extension-model", {
      name: "abc",
    });
    assert.strictEqual(record.upperName, "ABC");
  });

  test("addModelGetter is observable by classic observers (dependentKeyCompat)", async function (assert) {
    withPluginApi((api) => {
      api.addModelField("test-extension-model", "count", { defaultValue: 1 });
      api.addModelGetter("test-extension-model", "doubled", function () {
        return this.count * 2;
      });
    });

    const record = this.store.createRecord("test-extension-model", {
      name: "a",
    });
    assert.strictEqual(record.doubled, 2, "derives from the tracked field");

    // eslint-disable-next-line ember/no-observers -- verifies classic-observer interop
    addObserver(record, "doubled", () => assert.step("changed"));
    record.count = 5;
    await settled();

    assert.verifySteps(["changed"], "a classic observer fires on change");
    assert.strictEqual(record.doubled, 10);
  });

  test("addModelMethod adds an instance method", function (assert) {
    withPluginApi((api) =>
      api.addModelMethod("test-extension-model", "shout", function () {
        return `${this.name}!`;
      })
    );

    const record = this.store.createRecord("test-extension-model", {
      name: "hi",
    });
    assert.strictEqual(record.shout(), "hi!");
  });

  test("addModelSaveProperty includes the property in the save payload", async function (assert) {
    withPluginApi((api) => {
      api.addModelField("test-extension-model", "rank", { defaultValue: 0 });
      api.addModelSaveProperty("test-extension-model", "rank");
    });

    const record = this.store.createRecord("test-extension-model", {
      name: "a",
      rank: 7,
    });
    await record.save();

    assert.strictEqual(capturedCreateProps.rank, 7, "merged into the payload");
    assert.strictEqual(
      capturedCreateProps.name,
      "a",
      "keeps default properties"
    );
  });

  test("addModelSaveProperty accepts a value function", async function (assert) {
    withPluginApi((api) => {
      api.addModelSaveProperty(
        "test-extension-model",
        "custom_fields",
        function () {
          return { derived: this.name };
        }
      );
    });

    const record = this.store.createRecord("test-extension-model", {
      name: "a",
    });
    await record.save();

    assert.deepEqual(
      capturedCreateProps.custom_fields,
      { derived: "a" },
      "the computed value is merged into the payload"
    );
  });

  test("addModelCallback fires around the persistence lifecycle", async function (assert) {
    withPluginApi((api) => {
      api.addModelCallback("test-extension-model", "afterCreate", () =>
        assert.step("create")
      );
      api.addModelCallback("test-extension-model", "afterUpdate", () =>
        assert.step("update")
      );
    });

    const record = this.store.createRecord("test-extension-model", {
      name: "a",
    });

    await record.save();
    assert.verifySteps(["create"], "afterCreate fires on create");

    await record.save();
    assert.verifySteps(["update"], "afterUpdate fires on a subsequent save");
    assert.strictEqual(capturedUpdateProps.name, "a");
  });

  test("addModelCallback init fires after the create args are applied", function (assert) {
    const seen = [];
    withPluginApi((api) =>
      api.addModelCallback("test-extension-model", "init", function () {
        seen.push(this.name);
      })
    );

    this.store.createRecord("test-extension-model", { name: "a" });
    assert.deepEqual(seen, ["a"], "runs once, with the assigned args visible");
  });

  test("registerModelCallback expands the afterSave alias", function (assert) {
    registerModelCallback("widget", "afterSave", () =>
      assert.step("afterSave")
    );

    applyModelCallbacks("widget", "afterCreate", {}, {});
    applyModelCallbacks("widget", "afterUpdate", {}, {});

    assert.verifySteps(
      ["afterSave", "afterSave"],
      "runs for both create and update"
    );
  });

  test("registerModelCallback rejects unknown events", function (assert) {
    assert.throws(
      () => registerModelCallback("widget", "bogus", () => {}),
      /Unknown model callback event/
    );
  });

  test("applyModelCallbacks awaits async callbacks", async function (assert) {
    const steps = [];
    registerModelCallback("widget", "afterDestroy", async () => {
      await Promise.resolve();
      steps.push("callback");
    });

    await applyModelCallbacks("widget", "afterDestroy", {}, {});
    steps.push("after");

    assert.deepEqual(
      steps,
      ["callback", "after"],
      "the returned promise settles once async callbacks resolve"
    );
  });

  test("modelFieldNames returns the registered field names", function (assert) {
    registerModelField("widget", "a");
    registerModelField("widget", "b");

    assert.deepEqual(modelFieldNames("widget"), ["a", "b"]);
  });
});
