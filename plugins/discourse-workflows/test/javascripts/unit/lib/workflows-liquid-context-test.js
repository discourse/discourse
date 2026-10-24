import { module, test } from "qunit";
import {
  analyzeLiquidAt,
  buildLiquidScope,
  itemIndexAt,
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

function pathAtEnd(id, text, options) {
  return liquidPathForVariable(id, text, text.length, options);
}

module("Unit | lib | discourse-workflows | liquid-context", function () {
  module("buildLiquidScope", function () {
    test("exposes the all-items render context", function (assert) {
      const scope = buildLiquidScope({ branchFields: [INPUT_FIELDS] });

      assert.deepEqual(Object.keys(scope).sort(), [
        "execution",
        "inputs",
        "items",
        "items_count",
        "site_settings",
        "vars",
        "workflow",
      ]);
      assert.strictEqual(scope.items[0].topic.title, "");
      assert.strictEqual(scope.items[0].item_index, 1, "1-based, as rendered");
      assert.deepEqual(Object.keys(scope.items[0].item), ["json"]);
    });

    test("merges the current item into the root in per-item mode", function (assert) {
      const scope = buildLiquidScope({
        branchFields: [INPUT_FIELDS],
        perItem: true,
      });

      assert.strictEqual(scope.name, "");
      assert.strictEqual(scope.item.name, "");
      assert.strictEqual(scope.item_index, 1);
    });

    test("keeps each branch at its input index under inputs", function (assert) {
      const branchFields = [];
      branchFields[0] = INPUT_FIELDS;
      branchFields[2] = [{ key: "email", type: "string" }];
      const scope = buildLiquidScope({ branchFields });

      assert.deepEqual(scope.inputs[1], [], "a disconnected port stays empty");
      assert.strictEqual(scope.inputs[2][0].email, "");
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

  module("loopBindingsAt", function () {
    test("binds a loop variable to an element of its collection", function (assert) {
      const scope = buildLiquidScope({ branchFields: [INPUT_FIELDS] });
      const text = "{% for item in items %}{{ item.";
      const bindings = loopBindingsAt(scope, text, text.length);

      assert.strictEqual(bindings.item.topic.title, "");
      assert.strictEqual(bindings.forloop.index, 0);
    });

    test("resolves a nested loop through the enclosing one", function (assert) {
      const scope = buildLiquidScope({ branchFields: [INPUT_FIELDS] });
      const text =
        "{% for item in items %}{% for row in item.collected %}{{ row.";
      const bindings = loopBindingsAt(scope, text, text.length);

      assert.strictEqual(bindings.row.username, "");
    });
  });

  module("itemPrefixAt", function () {
    test("uses the innermost alias of a loop over the items", function (assert) {
      let text =
        "{% for entry in items offset: 1 reversed %}{% for row in entry.collected %}";
      assert.strictEqual(
        itemPrefixAt(text, text.length),
        "entry",
        "a nested loop over something else does not rebase the item"
      );

      text = "{% for entry in inputs[0] %}";
      assert.strictEqual(itemPrefixAt(text, text.length), "entry");
    });

    test("indexes back into the collection when the alias is shadowed", function (assert) {
      const text =
        "{% for item in inputs[0] %}{% for item in item.collected %}" +
        "{% for value in item.values %}";

      assert.strictEqual(
        itemPrefixAt(text, text.length),
        "inputs[0][forloop.parentloop.parentloop.index0]"
      );
    });

    test("is null when a shadowed loop has an offset", function (assert) {
      const text =
        "{% for item in items offset: 1 %}{% for item in item.collected %}";

      assert.strictEqual(itemPrefixAt(text, text.length), null);
    });

    test("ignores loops that are closed or inside comment and raw blocks", function (assert) {
      const closed = "{% for item in items %}x{% endfor %}y";
      assert.strictEqual(itemPrefixAt(closed, closed.length), "items[0]");

      for (const block of ["comment", "raw"]) {
        const live =
          `{% for item in items %}{%- ${block} -%}` +
          `{% endfor %}{% for ignored in items %}{%- end${block} -%}`;
        assert.strictEqual(itemPrefixAt(live, live.length), "item", block);

        const inactive = `{% ${block} %}{% for entry in items %}{% end${block} %}`;
        assert.strictEqual(
          itemPrefixAt(inactive, inactive.length),
          "items[0]",
          block
        );
      }

      const nested =
        "{% comment %}{% comment %}{% endcomment %}" +
        "{% for ignored in items %}{% endcomment %}";
      assert.strictEqual(itemPrefixAt(nested, nested.length), "items[0]");
    });

    test("addresses the current item by mode outside a loop over the items", function (assert) {
      const text = "{% for entry in inputs[2] %}";

      assert.strictEqual(itemPrefixAt(text, text.length), "items[0]");
      assert.strictEqual(
        itemPrefixAt(text, text.length, { perItem: true }),
        "item"
      );
    });

    test("addresses another branch's current item", function (assert) {
      const collection = "inputs[2]";

      assert.strictEqual(itemPrefixAt("", 0, { collection }), "inputs[2][0]");
      assert.strictEqual(
        itemPrefixAt("", 0, { collection, perItem: true }),
        null,
        "per-item mode walks the primary input only"
      );

      let text = "{% for entry in inputs[2] %}";
      assert.strictEqual(
        itemPrefixAt(text, text.length, { collection }),
        "entry"
      );

      text = "{% for item in items %}{% for t in item.tags %}";
      assert.strictEqual(
        itemPrefixAt(text, text.length, { collection }),
        "inputs[2][forloop.parentloop.index0]",
        "paired with the primary loop's index"
      );
    });
  });

  module("itemIndexAt", function () {
    test("is the forloop index of the loop over the items", function (assert) {
      const text = "{% for e in items %}{% for t in e.tags %}";

      assert.strictEqual(
        itemIndexAt(text, text.length),
        "forloop.parentloop.index0"
      );
    });

    test("counts from the end of a reversed loop", function (assert) {
      const text = "{% for e in items reversed limit: 2 %}";

      assert.strictEqual(itemIndexAt(text, text.length), "forloop.rindex0");
    });

    test("is null with an offset or outside a loop over the items", function (assert) {
      const offset = "{% for e in items offset: 1 %}";
      assert.strictEqual(itemIndexAt(offset, offset.length), null);

      const other = "{% for e in inputs[2] %}";
      assert.strictEqual(itemIndexAt(other, other.length), null);
      assert.strictEqual(itemIndexAt("", 0), null);
    });
  });

  module("liquidPathForVariable", function () {
    test("rewrites an input field against the current item", function (assert) {
      const inLoop = "{% for row in items %}";

      assert.strictEqual(
        pathAtEnd("$json.collected[0].username", ""),
        "items[0].collected[0].username"
      );
      assert.strictEqual(pathAtEnd("$json", "", { perItem: true }), "item");
      assert.strictEqual(pathAtEnd("$json.name", inLoop), "row.name");
      assert.strictEqual(
        pathAtEnd("name", inLoop),
        "row.name",
        "an unqualified field is an input field"
      );
    });

    test("renames the environment symbols the template exposes", function (assert) {
      assert.strictEqual(pathAtEnd("$vars.token", ""), "vars.token");
      assert.strictEqual(
        pathAtEnd("$site_settings.title", ""),
        "site_settings.title"
      );
      assert.strictEqual(pathAtEnd("$execution.id", ""), "execution.id");
    });

    test("rejects execution data the template does not expose", function (assert) {
      assert.strictEqual(pathAtEnd("$execution.called_by.id", ""), null);
      assert.strictEqual(pathAtEnd("$execution.resume_url", ""), null);
    });

    test("maps the item index onto the enclosing loop", function (assert) {
      const inLoop = "{% for row in items %}";

      assert.strictEqual(pathAtEnd("$itemIndex", inLoop), "forloop.index0");
      assert.strictEqual(pathAtEnd("$itemIndex", ""), null);
      assert.strictEqual(pathAtEnd("$itemIndex.x", inLoop), null);
    });

    test("rewrites another branch's fields against that branch", function (assert) {
      const prefix = '$("Right").all(0)[$itemIndex].json';
      const secondaryInputs = [{ prefix, inputIndex: 1 }];

      assert.strictEqual(
        pathAtEnd(`${prefix}.email`, "", { secondaryInputs }),
        "inputs[1][0].email"
      );
      assert.strictEqual(
        pathAtEnd(prefix, "", { secondaryInputs }),
        "inputs[1][0]"
      );
      assert.strictEqual(
        pathAtEnd(`${prefix}.email`, "", { secondaryInputs, perItem: true }),
        null,
        "no current item for the branch in per-item mode"
      );
      assert.strictEqual(
        pathAtEnd(`${prefix}x.email`, "", { secondaryInputs }),
        null,
        "a longer node name is not a match"
      );
    });

    test("accepts dotted and bracketed paths only", function (assert) {
      assert.strictEqual(
        pathAtEnd("$json.list.length", ""),
        "items[0].list.length"
      );
      assert.strictEqual(
        pathAtEnd('$json["a-b"][0]', ""),
        'items[0]["a-b"][0]'
      );
      assert.strictEqual(pathAtEnd("$json.a + 1", ""), null);
    });

    test("is null for a source the template cannot reach", function (assert) {
      assert.strictEqual(pathAtEnd("$('Other').item.json.id", ""), null);
      assert.strictEqual(pathAtEnd("$current_user.username", ""), null);
    });
  });
});
