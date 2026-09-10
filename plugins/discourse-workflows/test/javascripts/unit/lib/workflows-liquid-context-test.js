import { module, test } from "qunit";
import {
  analyzeLiquidAt,
  buildLiquidScope,
  enclosingLoopsAt,
  itemPrefixAt,
  liquidPathForVariable,
  loopBindingsAt,
  openDelimiterAt,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/liquid-context";

const INPUT_FIELDS = [
  { key: "name", id: "$json.name", type: "string" },
  {
    key: "topic",
    id: "$json.topic",
    type: "object",
    children: [{ key: "title", id: "$json.topic.title", type: "string" }],
  },
  {
    key: "collected",
    id: "$json.collected",
    type: "array",
    children: [
      {
        key: "0",
        id: "$json.collected[0]",
        type: "object",
        children: [
          {
            key: "username",
            id: "$json.collected[0].username",
            type: "string",
          },
        ],
      },
    ],
  },
];

module("Unit | lib | discourse-workflows | liquid-context", function () {
  module("buildLiquidScope", function () {
    test("exposes the all-items render context", function (assert) {
      const scope = buildLiquidScope({ inputFields: INPUT_FIELDS });

      assert.deepEqual(
        Object.keys(scope).sort(),
        [
          "execution",
          "inputs",
          "items",
          "items_count",
          "site_settings",
          "vars",
          "workflow",
        ],
        "only the shared keys are reachable outside per-item mode"
      );
      assert.strictEqual(
        scope.items[0].topic.title,
        "",
        "an item carries the input's json fields"
      );
      assert.strictEqual(
        scope.items[0].item_index,
        1,
        "an item exposes its 1-based index"
      );
      assert.deepEqual(
        Object.keys(scope.items[0].item),
        ["json"],
        "an item exposes the raw wrapper under item"
      );
    });

    test("merges the current item into the root in per-item mode", function (assert) {
      const scope = buildLiquidScope({
        inputFields: INPUT_FIELDS,
        perItem: true,
      });

      assert.strictEqual(scope.name, "", "json fields are reachable directly");
      assert.strictEqual(scope.item.name, "", "and through item");
      assert.strictEqual(scope.item_index, 1);
    });

    test("indexes each connected branch under inputs", function (assert) {
      const scope = buildLiquidScope({
        inputFields: INPUT_FIELDS,
        branchFields: [INPUT_FIELDS, [{ key: "other", type: "string" }]],
      });

      assert.strictEqual(scope.inputs.length, 2);
      assert.strictEqual(scope.inputs[1][0].other, "");
    });
  });

  module("openDelimiterAt", function () {
    test("reports the delimiter the position sits inside", function (assert) {
      assert.deepEqual(openDelimiterAt("a {{ b", 6), {
        delimiter: "output",
        open: 2,
      });
      assert.deepEqual(openDelimiterAt("{% for ", 7), {
        delimiter: "tag",
        open: 0,
      });
    });

    test("returns null once the delimiter is closed", function (assert) {
      assert.strictEqual(openDelimiterAt("{{ a }} b", 9), null);
      assert.strictEqual(openDelimiterAt("plain text", 5), null);
    });
  });

  module("analyzeLiquidAt", function () {
    test("completes a tag name at the start of a tag", function (assert) {
      assert.deepEqual(analyzeLiquidAt("{% fo", 5), {
        kind: "tagName",
        delimiter: "tag",
        partial: "fo",
        from: 3,
      });
    });

    test("completes a tag name after whitespace control", function (assert) {
      assert.deepEqual(analyzeLiquidAt("{%- fo", 6), {
        kind: "tagName",
        delimiter: "tag",
        partial: "fo",
        from: 4,
      });
      assert.deepEqual(analyzeLiquidAt("{%-fo", 5), {
        kind: "tagName",
        delimiter: "tag",
        partial: "fo",
        from: 3,
      });
    });

    test("completes a filter after a pipe", function (assert) {
      assert.deepEqual(analyzeLiquidAt("{{ name | upc", 13), {
        kind: "filter",
        delimiter: "output",
        partial: "upc",
        from: 10,
      });
    });

    test("splits a dotted path into object and partial", function (assert) {
      assert.deepEqual(analyzeLiquidAt("{{ item.topic.ti", 16), {
        kind: "property",
        delimiter: "output",
        object: "item.topic",
        partial: "ti",
        from: 14,
      });
    });

    test("treats a bare word as a root lookup", function (assert) {
      assert.deepEqual(analyzeLiquidAt("{{ ite", 6), {
        kind: "root",
        delimiter: "output",
        partial: "ite",
        from: 3,
      });
    });

    test("is null outside a delimiter", function (assert) {
      assert.strictEqual(analyzeLiquidAt("hello", 5), null);
    });
  });

  module("enclosingLoopsAt", function () {
    test("tracks nesting across for and endfor", function (assert) {
      const text = [
        "{% for item in items -%}",
        "{% for row in item.collected -%}",
        "",
      ].join("\n");

      assert.deepEqual(enclosingLoopsAt(text, text.length), [
        { name: "item", path: "items" },
        { name: "row", path: "item.collected" },
      ]);
    });

    test("drops a loop once it is closed", function (assert) {
      const text = "{% for item in items %}x{% endfor %}y";

      assert.deepEqual(enclosingLoopsAt(text, text.length), []);
    });
  });

  module("loopBindingsAt", function () {
    test("binds a loop variable to an element of its collection", function (assert) {
      const scope = buildLiquidScope({ inputFields: INPUT_FIELDS });
      const text = "{% for item in items %}{{ item.";
      const bindings = loopBindingsAt(scope, text, text.length);

      assert.strictEqual(bindings.item.topic.title, "");
      assert.strictEqual(bindings.forloop.index, 0, "forloop comes into scope");
    });

    test("resolves a nested loop through the enclosing one", function (assert) {
      const scope = buildLiquidScope({ inputFields: INPUT_FIELDS });
      const text =
        "{% for item in items %}{% for row in item.collected %}{{ row.";
      const bindings = loopBindingsAt(scope, text, text.length);

      assert.strictEqual(bindings.row.username, "");
    });
  });

  module("itemPrefixAt", function () {
    test("prefers the innermost loop variable", function (assert) {
      const text = "{% for entry in items %}";

      assert.strictEqual(itemPrefixAt(text, text.length), "entry");
    });

    test("addresses the current item by mode outside a loop", function (assert) {
      assert.strictEqual(itemPrefixAt("", 0), "items[0]");
      assert.strictEqual(itemPrefixAt("", 0, { perItem: true }), "item");
    });
  });

  module("liquidPathForVariable", function () {
    test("rewrites an input field against the item prefix", function (assert) {
      assert.strictEqual(
        liquidPathForVariable("$json.topic.title", "item"),
        "item.topic.title"
      );
      assert.strictEqual(
        liquidPathForVariable("$json.collected[0].username", "items[0]"),
        "items[0].collected[0].username"
      );
      assert.strictEqual(liquidPathForVariable("$json", "item"), "item");
    });

    test("renames the environment symbols it can reach", function (assert) {
      assert.strictEqual(
        liquidPathForVariable("$vars.token", "item"),
        "vars.token"
      );
      assert.strictEqual(
        liquidPathForVariable("$site_settings.title", "item"),
        "site_settings.title"
      );
      assert.strictEqual(
        liquidPathForVariable("$itemIndex", "item"),
        "item_index"
      );
    });

    test("is null for a source the template cannot reach", function (assert) {
      assert.strictEqual(
        liquidPathForVariable("$('Other').item.json.id", "item"),
        null
      );
      assert.strictEqual(
        liquidPathForVariable("$current_user.username", "item"),
        null
      );
    });
  });
});
