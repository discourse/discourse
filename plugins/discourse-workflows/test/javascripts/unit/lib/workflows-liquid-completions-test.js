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

function complete(
  text,
  {
    explicit = false,
    scope = () => buildLiquidScope({ branchFields: [INPUT_FIELDS] }),
  } = {}
) {
  const source = liquidCompletionSource({ scope, sections: SECTIONS });

  return source({
    state: { doc: { toString: () => text } },
    pos: text.length,
    explicit,
  });
}

function labels(result) {
  return (result?.options || []).map((candidate) => candidate.label);
}

function option(result, label) {
  return result.options.find((candidate) => candidate.label === label);
}

module("Unit | lib | discourse-workflows | liquid-completions", function () {
  test("offers nothing in plain template text", function (assert) {
    assert.strictEqual(complete("Items: "), null);
  });

  test("offers tag names at the start of a tag", function (assert) {
    const result = complete("{% fo");

    assert.strictEqual(option(result, "for").apply, "for ");
    assert.strictEqual(
      option(result, "endfor").apply,
      "endfor",
      "a closing tag takes no arguments"
    );
    assert.false(labels(result).includes("render"));
  });

  test("offers filters after a pipe", function (assert) {
    const result = complete("{{ name | up");

    assert.true(labels(result).includes("upcase"));
    assert.false(labels(result).includes("for"));
  });

  test("offers the render context at the root of an output tag", function (assert) {
    assert.true(labels(complete("{{ it")).includes("items"));
    assert.strictEqual(complete("{{ "), null, "not before a partial");
    assert.true(
      labels(complete("{{ ", { explicit: true })).includes("items"),
      "unless asked"
    );
  });

  test("resolves properties through a loop variable", function (assert) {
    const result = complete("{% for row in items %}{{ row.");

    assert.true(labels(result).includes("item_index"));
    assert.strictEqual(
      option(result, "topic").apply,
      "topic.",
      "an object re-opens completion at the next level"
    );
    assert.deepEqual(labels(complete("{% for row in items %}{{ row.topic.")), [
      "title",
    ]);
  });

  test("brings the loop variable into the root context", function (assert) {
    const result = complete("{% for row in items %}{{ ro");

    assert.true(labels(result).includes("row"));
    assert.true(labels(result).includes("forloop"));
  });

  test("offers nothing for a path that does not resolve", function (assert) {
    assert.strictEqual(complete("{{ nope."), null);
  });

  test("reads the render context on every request", function (assert) {
    let perItem = false;
    const scope = () =>
      buildLiquidScope({ branchFields: [INPUT_FIELDS], perItem });

    assert.false(labels(complete("{{ item", { scope })).includes("item_index"));

    perItem = true;

    assert.true(labels(complete("{{ item", { scope })).includes("item_index"));
  });
});
