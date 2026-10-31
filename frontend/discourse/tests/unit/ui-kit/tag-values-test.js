import { module, test } from "qunit";
import { serializeTags } from "discourse/lib/serialize-tags";
import {
  createTagItem,
  emitTags,
  tagFromItem,
  tagItem,
  tagKey,
} from "discourse/ui-kit/select/recipes/tags/-internals/tag-values";

module("Unit | ui-kit | select | recipes | tag values", function () {
  test("tagKey follows serializeTags' id rules", function (assert) {
    const cases = [
      [{ id: 5, name: "five" }, 5, "a numeric id"],
      [{ id: "5", name: "five" }, 5, "a numeric string id"],
      [{ id: "foo", name: "Foo", isNew: true }, "tag-name:foo", "a new tag"],
      [
        { id: "5", name: "5", isNew: true },
        "tag-name:5",
        "isNew wins over a numeric id",
      ],
      ["Foo", "tag-name:foo", "a plain name"],
      ["5", "tag-name:5", "a numeric-looking name is still a name"],
      [7, 7, "a bare number is an id"],
      [{ name: "Bar" }, "tag-name:bar", "a name-only object"],
      [{ id: 0, name: "Zero" }, "tag-name:zero", "a non-positive id"],
      [{ id: "abc", name: "Abc" }, "tag-name:abc", "a non-numeric id"],
    ];
    for (const [tag, expected, label] of cases) {
      assert.strictEqual(tagKey(tag), expected, label);
    }
  });

  test("a created item is keyed by name and flagged new", function (assert) {
    assert.deepEqual(createTagItem("Foo"), {
      id: "tag-name:foo",
      name: "Foo",
      isNew: true,
    });
  });

  test("tagFromItem returns select-kit's shapes", function (assert) {
    assert.deepEqual(tagFromItem(createTagItem("Foo")), {
      id: "Foo",
      name: "Foo",
      isNew: true,
    });
    const row = { id: 5, name: "five", count: 3 };
    assert.strictEqual(tagFromItem(row), row, "a server row passes through");
  });

  test("keys round-trip through emitted tags", function (assert) {
    for (const item of [{ id: 5, name: "five" }, createTagItem("New one")]) {
      assert.strictEqual(tagKey(tagFromItem(item)), item.id, item.name);
    }
  });

  test("tagItem turns a held tag into an engine item", function (assert) {
    assert.deepEqual(tagItem("foo"), { id: "tag-name:foo", name: "foo" });
    assert.deepEqual(tagItem(7), { id: 7, name: "7" });
    assert.deepEqual(tagItem({ id: "5", name: "five" }), {
      id: 5,
      name: "five",
    });
    assert.deepEqual(tagItem({ id: "x", name: "X", isNew: true }), {
      id: "tag-name:x",
      name: "X",
      isNew: true,
    });
    assert.deepEqual(tagItem({ name: "Bar" }), {
      id: "tag-name:bar",
      name: "Bar",
    });
  });

  test("emitTags keeps held objects and converts the rest", function (assert) {
    const heldObject = { id: 5, name: "five", extra: true };
    const held = [heldObject, "foo", 9, "5"];
    const created = createTagItem("Brand New");
    const row = { id: 11, name: "eleven" };

    const emitted = emitTags(
      [5, "tag-name:foo", 9, "tag-name:5", 11, created.id],
      { held, items: [row, created] }
    );

    assert.strictEqual(
      emitted[0],
      heldObject,
      "a held object keeps its identity"
    );
    assert.deepEqual(
      emitted[1],
      { name: "foo" },
      "a held string becomes {name}"
    );
    assert.deepEqual(
      emitted[2],
      { id: 9, name: "9" },
      "a held number keeps its id"
    );
    assert.deepEqual(
      emitted[3],
      { name: "5" },
      "a held '5' is a name, never id 5"
    );
    assert.strictEqual(emitted[4], row, "a picked server row is the row");
    assert.deepEqual(emitted[5], {
      id: "Brand New",
      name: "Brand New",
      isNew: true,
    });

    assert.deepEqual(
      serializeTags(emitted),
      [
        { id: 5, name: "five" },
        { name: "foo" },
        { id: 9, name: "9" },
        { name: "5" },
        { id: 11, name: "eleven" },
        { name: "Brand New" },
      ],
      "what the server receives"
    );
  });
});
