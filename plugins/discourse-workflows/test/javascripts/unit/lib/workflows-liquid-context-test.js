import { module, test } from "qunit";
import {
  buildLiquidScope,
  describeScopePath,
  itemIndex,
  itemPrefix,
  liquidPathForVariable,
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

  module("describeScopePath", function () {
    test("puts what a template is built around first", function (assert) {
      const variable = { variable: true };
      assert.deepEqual(describeScopePath(["items"], [], variable), {
        detail: "array",
        boost: 10,
        section: { name: "Recommended", rank: 0 },
      });
      assert.deepEqual(describeScopePath(["workflow"], {}, variable), {
        detail: "object",
        boost: undefined,
        section: { name: "Metadata", rank: 3 },
      });
      assert.deepEqual(
        describeScopePath(["item", "name"], "", { variable: false }),
        {
          detail: "string",
          boost: undefined,
          section: { name: "Properties", rank: 2 },
        }
      );
      assert.strictEqual(
        describeScopePath(["total"], undefined, variable).detail,
        undefined,
        "a value the editor cannot tell has no detail"
      );
    });
  });

  module("itemPrefix", function () {
    test("uses the current alias even with an offset", function (assert) {
      assert.strictEqual(
        itemPrefix([{ name: "entry", path: "items", offset: true }]),
        "entry"
      );
    });

    test("indexes back into a collection when its alias is shadowed", function (assert) {
      const loops = [
        { name: "item", path: "inputs[0]" },
        { name: "item", path: "item.collected" },
        { name: "value", path: "item.values" },
      ];
      assert.strictEqual(
        itemPrefix(loops),
        "inputs[0][forloop.parentloop.parentloop.index0]"
      );
      loops[0].offset = true;
      assert.strictEqual(
        itemPrefix(loops),
        null,
        "an offset makes source indexing uncertain"
      );
    });

    test("uses the run mode outside a primary loop", function (assert) {
      const loops = [{ name: "other", path: "inputs[2]" }];
      assert.strictEqual(itemPrefix(loops), "items[0]");
      assert.strictEqual(itemPrefix(loops, { perItem: true }), "item");
      assert.strictEqual(
        itemPrefix([], { collection: "inputs[2]", perItem: true }),
        null
      );
    });

    test("pairs other inputs with the primary loop index", function (assert) {
      const loops = [
        { name: "entry", path: "items" },
        { name: "tag", path: "entry.tags" },
      ];
      assert.strictEqual(
        itemPrefix(loops, { collection: "inputs[2]" }),
        "inputs[2][forloop.parentloop.index0]"
      );
      loops[0].reversed = true;
      assert.strictEqual(itemIndex(loops), "forloop.parentloop.rindex0");
      loops[0].offset = true;
      assert.strictEqual(itemIndex(loops), null);
    });
  });

  module("liquidPathForVariable", function () {
    test("maps item fields and index onto their current loop", function (assert) {
      const loops = [{ name: "row", path: "items" }];
      assert.strictEqual(
        liquidPathForVariable("$json.collected[0].username", []),
        "items[0].collected[0].username"
      );
      assert.strictEqual(
        liquidPathForVariable("$json", [], { perItem: true }),
        "item"
      );
      assert.strictEqual(
        liquidPathForVariable("$json.name", loops),
        "row.name"
      );
      assert.strictEqual(liquidPathForVariable("name", loops), "row.name");
      assert.strictEqual(
        liquidPathForVariable("$itemIndex", loops),
        "forloop.index0"
      );
      assert.strictEqual(liquidPathForVariable("$itemIndex", []), null);
      assert.strictEqual(liquidPathForVariable("$itemIndex.x", loops), null);
    });

    test("maps only environment symbols exposed by the renderer", function (assert) {
      assert.strictEqual(
        liquidPathForVariable("$vars.token", []),
        "vars.token"
      );
      assert.strictEqual(
        liquidPathForVariable("$site_settings.title", []),
        "site_settings.title"
      );
      assert.strictEqual(
        liquidPathForVariable("$execution.id", []),
        "execution.id"
      );
      assert.strictEqual(
        liquidPathForVariable("$execution.called_by.id", []),
        null
      );
      assert.strictEqual(
        liquidPathForVariable("$execution.resume_url", []),
        null
      );
      assert.strictEqual(
        liquidPathForVariable("$current_user.username", []),
        null
      );
    });

    test("rewrites another branch against its connected input", function (assert) {
      const prefix = '$("Right").all(0)[$itemIndex].json';
      const secondaryInputs = [{ prefix, inputIndex: 1 }];
      assert.strictEqual(
        liquidPathForVariable(`${prefix}.email`, [], { secondaryInputs }),
        "inputs[1][0].email"
      );
      assert.strictEqual(
        liquidPathForVariable(prefix, [], { secondaryInputs }),
        "inputs[1][0]"
      );
      assert.strictEqual(
        liquidPathForVariable(`${prefix}.email`, [], {
          secondaryInputs,
          perItem: true,
        }),
        null
      );
      assert.strictEqual(
        liquidPathForVariable(`${prefix}x.email`, [], { secondaryInputs }),
        null
      );
      assert.strictEqual(
        liquidPathForVariable("$('Other').item.json.id", []),
        null
      );
    });

    test("accepts paths, not arbitrary expressions", function (assert) {
      assert.strictEqual(
        liquidPathForVariable('$json["a-b"][0]', []),
        'items[0]["a-b"][0]'
      );
      assert.strictEqual(liquidPathForVariable("$json.a + 1", []), null);
    });
  });
});
