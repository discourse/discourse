import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { serializeTags } from "discourse/lib/serialize-tags";

module("Unit | Utility | serialize-tags", function (hooks) {
  setupTest(hooks);

  test("plain string tag names are serialized as name-only", function (assert) {
    assert.deepEqual(serializeTags(["10"]), [{ name: "10" }]);
    assert.deepEqual(serializeTags(["foo"]), [{ name: "foo" }]);
  });

  test("existing tags with numeric id are serialized with id and name", function (assert) {
    assert.deepEqual(serializeTags([{ id: 10, name: "bulk-test-tag-10" }]), [
      { id: 10, name: "bulk-test-tag-10" },
    ]);
  });

  test("isNew items are serialized as name-only, even when id looks numeric", function (assert) {
    assert.deepEqual(serializeTags([{ id: "10", name: "10", isNew: true }]), [
      { name: "10" },
    ]);
  });

  test("mixed input: existing tag alongside a freshly created numeric-name tag", function (assert) {
    assert.deepEqual(
      serializeTags([
        { id: 42, name: "bulk-test-tag-10" },
        { id: "10", name: "10", isNew: true },
      ]),
      [{ id: 42, name: "bulk-test-tag-10" }, { name: "10" }]
    );
  });

  test("non-numeric id falls back to name-only", function (assert) {
    assert.deepEqual(serializeTags([{ id: "hello", name: "hello" }]), [
      { name: "hello" },
    ]);
  });
});
