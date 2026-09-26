import { Schema } from "prosemirror-model";
import { module, test } from "qunit";
import { createSchema } from "discourse/static/prosemirror/core/schema";
import Serializer from "discourse/static/prosemirror/core/serializer";

module("Unit | Static | ProseMirror | serializer", function () {
  test("preserves marks in inline slices and fragments", function (assert) {
    const schema = createSchema([]);
    const serializer = new Serializer([]);
    const doc = schema.node("doc", null, [
      schema.node("paragraph", null, [
        schema.text("bold", [schema.marks.strong.create()]),
        schema.text(" and "),
        schema.text("italic", [schema.marks.em.create()]),
      ]),
    ]);
    const slice = doc.slice(1, doc.content.size - 1);
    assert.strictEqual(
      serializer.convert(slice),
      "**bold** and *italic*",
      "an inline slice retains both marks"
    );
    assert.strictEqual(
      serializer.convert(slice.content),
      "**bold** and *italic*",
      "an inline fragment retains both marks"
    );
    assert.strictEqual(
      serializer.convert(doc.content),
      "**bold** and *italic*",
      "a block fragment is still serialized correctly"
    );
  });

  test("supports an inline document without a paragraph type", function (assert) {
    const schema = new Schema({
      nodes: { doc: { content: "text*" }, text: {} },
    });
    const serializer = new Serializer([]);
    assert.strictEqual(
      serializer.convert(schema.node("doc", null, schema.text("hello"))),
      "hello",
      "minimal schemas can serialize inline documents"
    );
  });
});
