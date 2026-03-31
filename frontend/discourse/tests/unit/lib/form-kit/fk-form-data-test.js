import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FKFormData from "discourse/form-kit/lib/fk-form-data";

module("Unit | Lib | FormKit | FKFormData", function (hooks) {
  setupTest(hooks);

  test("commitField - commits the draft value as the new baseline", function (assert) {
    const formData = new FKFormData({ foo: "original", bar: 1 });

    formData.set("foo", "changed");
    formData.commitField("foo");

    assert.strictEqual(
      formData.data.foo,
      "changed",
      "baseline data is updated to the draft value"
    );
    assert.strictEqual(
      formData.draftData.foo,
      "changed",
      "draft data still holds the committed value"
    );
  });

  test("commitField - removes only patches for the committed field", function (assert) {
    const formData = new FKFormData({ foo: "a", bar: "b" });

    formData.set("foo", "a2");
    formData.set("bar", "b2");

    assert.true(formData.patches.length >= 2, "patches exist for both fields");

    formData.commitField("foo");

    const remainingPaths = formData.patches.map((p) => p.path[0]);
    assert.false(
      remainingPaths.includes("foo"),
      "patches for 'foo' are removed"
    );
    assert.true(
      remainingPaths.includes("bar"),
      "patches for 'bar' are preserved"
    );
  });

  test("commitField - field is no longer dirty after commit", function (assert) {
    const formData = new FKFormData({ foo: "a" });

    formData.set("foo", "a2");
    assert.true(formData.isDirty, "dirty after change");

    formData.commitField("foo");
    assert.false(
      formData.isDirty,
      "not dirty after committing the only changed field"
    );
  });

  test("commitField - other fields remain dirty", function (assert) {
    const formData = new FKFormData({ foo: "a", bar: "b" });

    formData.set("foo", "a2");
    formData.set("bar", "b2");
    formData.commitField("foo");

    assert.true(
      formData.isDirty,
      "still dirty because 'bar' has uncommitted changes"
    );
  });

  test("commitField - committed field survives reset", async function (assert) {
    const formData = new FKFormData({ foo: "a", bar: "b" });

    formData.set("foo", "a2");
    formData.set("bar", "b2");
    formData.commitField("foo");

    await formData.rollback();

    assert.strictEqual(
      formData.draftData.foo,
      "a2",
      "'foo' keeps its committed value after rollback"
    );
    assert.strictEqual(
      formData.draftData.bar,
      "b",
      "'bar' reverts to original value after rollback"
    );
  });
});
