import { module, test } from "qunit";
import {
  inputFieldPrefixForConnection,
  nodeOutputFirstJsonPath,
  nodeOutputItemJsonPath,
  nodeOutputJsonPath,
  nodeOutputLinkedItemJsonPath,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-paths";

module("Unit | lib | discourse-workflows | expression-paths", function () {
  test("nodeOutputFirstJsonPath escapes node names and output indexes for expressions", function (assert) {
    assert.strictEqual(
      nodeOutputFirstJsonPath('Fetch "quoted" \\ data', { outputIndex: 1 }),
      '$("Fetch \\"quoted\\" \\\\ data").first(1).json'
    );
    assert.strictEqual(
      nodeOutputFirstJsonPath("Fetch data"),
      '$("Fetch data").first().json'
    );
  });

  test("nodeOutputLinkedItemJsonPath escapes node names for expressions", function (assert) {
    assert.strictEqual(
      nodeOutputLinkedItemJsonPath('Fetch "quoted" \\ data'),
      '$("Fetch \\"quoted\\" \\\\ data").item.json'
    );
  });

  test("nodeOutputJsonPath uses the simplest safe output expression", function (assert) {
    const runData = {
      Aggregate: [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { markdown: "summary" } }],
              item_count: 1,
            },
          ],
        },
      ],
      "Per item": [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { name: "Ada" } }, { json: { name: "Grace" } }],
              item_count: 2,
            },
          ],
        },
      ],
    };

    assert.strictEqual(
      nodeOutputJsonPath(runData, "Aggregate"),
      '$("Aggregate").first().json'
    );
    assert.strictEqual(
      nodeOutputJsonPath(runData, "Per item"),
      '$("Per item").item.json'
    );
    assert.strictEqual(
      nodeOutputJsonPath(runData, "Aggregate", { itemCount: 2 }),
      '$("Aggregate").item.json',
      "an effective pinned item count overrides the stale run count"
    );
  });

  test("nodeOutputItemJsonPath builds explicit output and item index references", function (assert) {
    assert.strictEqual(
      nodeOutputItemJsonPath("Second input", { outputIndex: 1 }),
      '$("Second input").all(1)[$itemIndex].json'
    );
  });

  test("inputFieldPrefixForConnection uses $json only for the primary input connection", function (assert) {
    const primaryConnection = {
      sourceClientId: "left",
      targetClientId: "merge",
      targetInputIndex: 0,
    };
    const secondaryConnection = {
      sourceClientId: "right",
      targetClientId: "merge",
      targetInputIndex: 1,
      sourceOutputIndex: 2,
    };

    assert.strictEqual(
      inputFieldPrefixForConnection(
        primaryConnection,
        { name: "Left" },
        { primaryConnection }
      ),
      "$json"
    );
    assert.strictEqual(
      inputFieldPrefixForConnection(
        secondaryConnection,
        { name: "Right" },
        { primaryConnection }
      ),
      '$("Right").all(2)[$itemIndex].json'
    );
  });
});
