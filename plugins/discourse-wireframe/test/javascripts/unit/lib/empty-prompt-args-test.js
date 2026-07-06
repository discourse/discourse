import { module, test } from "qunit";
import { emptyPromptArgEntries } from "discourse/plugins/discourse-wireframe/discourse/lib/empty-prompt-args";

const SCHEMA = {
  topicId: {
    type: "number",
    ui: { control: "topic-select", emptyPrompt: "Choose a topic to feature." },
  },
  showExcerpt: { type: "boolean", ui: { control: "toggle" } },
};

module("Unit | Wireframe | empty-prompt-arg primitives", function () {
  test("returns nothing when no arg declares an empty prompt", function (assert) {
    const schema = { title: { type: "string" } };
    assert.deepEqual(emptyPromptArgEntries(schema, {}), []);
  });

  test("lists a prompt arg only while it is unset", function (assert) {
    const unset = emptyPromptArgEntries(SCHEMA, {});
    assert.deepEqual(
      unset.map((e) => e.name),
      ["topicId"],
      "an unset prompt arg is surfaced"
    );
    assert.strictEqual(
      unset[0].prompt,
      "Choose a topic to feature.",
      "carries the resolved prompt text"
    );

    const filled = emptyPromptArgEntries(SCHEMA, { topicId: 42 });
    assert.deepEqual(filled, [], "a filled prompt arg is not surfaced");
  });

  test("treats nullish values as unset", function (assert) {
    assert.strictEqual(
      emptyPromptArgEntries(SCHEMA, { topicId: null }).length,
      1
    );
    assert.strictEqual(
      emptyPromptArgEntries(SCHEMA, { topicId: undefined }).length,
      1
    );
  });

  test("ignores an empty-string prompt", function (assert) {
    const schema = { topicId: { type: "number", ui: { emptyPrompt: "" } } };
    assert.deepEqual(emptyPromptArgEntries(schema, {}), []);
  });

  test("tolerates a missing args object", function (assert) {
    assert.strictEqual(emptyPromptArgEntries(SCHEMA, null).length, 1);
  });

  test("tolerates a null/undefined schema", function (assert) {
    assert.deepEqual(emptyPromptArgEntries(null, {}), []);
    assert.deepEqual(emptyPromptArgEntries(undefined, {}), []);
  });
});
