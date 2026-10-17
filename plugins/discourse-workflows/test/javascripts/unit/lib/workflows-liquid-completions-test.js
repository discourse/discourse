import { module, test } from "qunit";
import { buildLiquidScope } from "discourse/plugins/discourse-workflows/admin/lib/workflows/liquid-context";
import { liquidCompletionSource } from "discourse/plugins/discourse-workflows/admin/lib/workflows/liquid-extensions/completions";

const INPUT_FIELDS = [
  { key: "name", id: "$json.name", type: "string" },
  {
    key: "topic",
    id: "$json.topic",
    type: "object",
    children: [{ key: "title", id: "$json.topic.title", type: "string" }],
  },
];

const SECTIONS = {
  recommended: "recommended",
  properties: "properties",
  metadata: "metadata",
  tags: "tags",
  filters: "filters",
};

// The source only reads `doc.toString()`, `pos` and `explicit`, so a plain
// object stands in for the editor's completion context.
function complete(text, { perItem = false, explicit = false } = {}) {
  const source = liquidCompletionSource({
    scope: buildLiquidScope({ inputFields: INPUT_FIELDS, perItem }),
    sections: SECTIONS,
  });

  return source({
    state: { doc: { toString: () => text } },
    pos: text.length,
    explicit,
  });
}

function labels(result) {
  return (result?.options || []).map((option) => option.label);
}

module("Unit | lib | discourse-workflows | liquid-completions", function () {
  test("offers nothing in plain template text", function (assert) {
    assert.strictEqual(complete("Items: "), null);
  });

  test("offers tag names at the start of a tag", function (assert) {
    const result = complete("{% fo");

    assert.true(labels(result).includes("for"));
    assert.true(labels(result).includes("endfor"), "including closing tags");
    assert.strictEqual(result.from, 3, "replaces the partial tag name");
  });

  test("offers filters after a pipe", function (assert) {
    const result = complete("{{ name | up");

    assert.true(labels(result).includes("upcase"));
    assert.false(
      labels(result).includes("for"),
      "tags are not offered in a filter position"
    );
  });

  test("offers the render context at the root of an output tag", function (assert) {
    const result = complete("{{ it");

    assert.deepEqual(
      labels(result).sort(),
      [
        "execution",
        "inputs",
        "items",
        "items_count",
        "site_settings",
        "vars",
        "workflow",
      ],
      "only what the render context provides"
    );
  });

  test("offers the current item's fields at the root in per-item mode", function (assert) {
    const result = complete("{{ na", { perItem: true });

    assert.true(labels(result).includes("name"), "the item's json fields");
    assert.true(labels(result).includes("item_index"));
  });

  test("resolves properties of a loop variable", function (assert) {
    const result = complete("{% for row in items %}{{ row.");

    assert.true(labels(result).includes("topic"));
    assert.true(labels(result).includes("item_index"));
    assert.strictEqual(
      result.options.find((option) => option.label === "topic").apply,
      "topic.",
      "an object re-opens completion at the next level"
    );
  });

  test("resolves a property path several levels deep", function (assert) {
    const result = complete("{% for row in items %}{{ row.topic.");

    assert.deepEqual(labels(result), ["title"]);
  });

  test("brings the loop variable into the root context", function (assert) {
    const result = complete("{% for row in items %}{{ ro");

    assert.true(labels(result).includes("row"));
    assert.true(labels(result).includes("forloop"));
  });

  test("drops a loop variable once the loop is closed", function (assert) {
    const result = complete("{% for row in items %}{% endfor %}{{ ro");

    assert.false(labels(result).includes("row"));
  });

  test("offers nothing for a path that does not resolve", function (assert) {
    assert.strictEqual(complete("{{ nope."), null);
  });

  test("follows a render context that changes after the editor is built", function (assert) {
    let perItem = false;
    const source = liquidCompletionSource({
      scope: () => buildLiquidScope({ inputFields: INPUT_FIELDS, perItem }),
      sections: SECTIONS,
    });
    const offered = (text) =>
      (
        source({
          state: { doc: { toString: () => text } },
          pos: text.length,
          explicit: false,
        })?.options || []
      ).map((option) => option.label);

    assert.false(
      offered("{{ item").includes("item_index"),
      "the current item is out of scope for all items"
    );

    perItem = true;

    assert.true(
      offered("{{ item").includes("item_index"),
      "switching mode brings it into scope without rebuilding the editor"
    );
  });
});
