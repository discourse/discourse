import { module, test } from "qunit";
import { createSchema } from "discourse/static/prosemirror/core/schema";
import Serializer from "discourse/static/prosemirror/core/serializer";
import strikethrough from "discourse/static/prosemirror/extensions/strikethrough";

module(
  "Unit | Static | ProseMirror | expel-boundary-punctuation",
  function (hooks) {
    let schema, serializer;

    hooks.beforeEach(function () {
      // strikethrough supplies its `~~` mark alongside the strong/em defaults
      schema = createSchema([strikethrough]);
      serializer = new Serializer([strikethrough]);
    });

    // Builds these doc states directly since no markdown source produces them.
    function paragraph(...runs) {
      const content = runs.map(([text, ...marks]) =>
        schema.text(
          text,
          marks.map((name) => schema.marks[name].create())
        )
      );
      return schema.node("doc", null, [
        schema.node("paragraph", null, content),
      ]);
    }

    function serialize(...runs) {
      return serializer.convert(paragraph(...runs));
    }

    test("expels trailing punctuation that would break the closing delimiter", function (assert) {
      assert.strictEqual(
        serialize(["text.", "strong"], ["text"]),
        "**text**.text"
      );
      assert.strictEqual(serialize(["text.", "em"], ["text"]), "*text*.text");
      assert.strictEqual(
        serialize(["text.", "strikethrough"], ["text"]),
        "~~text~~.text"
      );
    });

    test("expels leading punctuation that would break the opening delimiter", function (assert) {
      assert.strictEqual(
        serialize(["text"], [".word", "strong"]),
        "text.**word**"
      );
    });

    test("expels a run of consecutive boundary punctuation", function (assert) {
      assert.strictEqual(
        serialize(["text..", "strong"], ["text"]),
        "**text**..text"
      );
    });

    test("leaves valid boundaries untouched", function (assert) {
      assert.strictEqual(serialize(["Hello.", "strong"]), "**Hello.**");
      assert.strictEqual(
        serialize(["Hello.", "strong"], [" world"]),
        "**Hello.** world"
      );
      assert.strictEqual(serialize(["Hello", "strong"], ["!"]), "**Hello**!");
      assert.strictEqual(
        serialize(["text", "strong"], ["text"]),
        "**text**text"
      );
    });

    test("handles nested strong/em ending in punctuation", function (assert) {
      assert.strictEqual(
        serialize(["text.", "strong", "em"], ["text"]),
        "***text***.text"
      );
    });

    test("passes selection slices through untouched", function (assert) {
      const doc = paragraph(["text.", "strong"], ["text"]);
      assert.strictEqual(
        serializer.convert(doc.slice(0, doc.content.size)),
        "**text.**text"
      );
    });
  }
);
