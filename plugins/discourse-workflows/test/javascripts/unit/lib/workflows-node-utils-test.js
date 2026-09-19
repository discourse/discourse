import { module, test } from "qunit";
import {
  NODE_WIDTH,
  nodeDescription,
  nodeWidth,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/node-utils";

module("Unit | Utility | workflows node utils", function () {
  test("keeps the base width for single-output nodes", function (assert) {
    assert.strictEqual(nodeWidth({ type: "trigger:manual" }), NODE_WIDTH);
  });

  test("reserves extra width for branching output labels", function (assert) {
    const nodeType = {
      identifier: "action:data_table",
      ports: [
        {
          key: "results",
          primary: true,
          label: "Results",
        },
        {
          key: "no_results",
          label: "No results",
        },
      ],
    };

    assert.true(
      nodeWidth({ type: "action:data_table" }, { nodeType }) > NODE_WIDTH
    );
  });

  test("can infer branch width from output keys alone", function (assert) {
    assert.true(
      nodeWidth(
        { type: "action:data_table" },
        { outputKeys: ["results", "no_results"] }
      ) > NODE_WIDTH
    );
  });

  test("nodeDescription only displays notes when notesInFlow is enabled", function (assert) {
    assert.strictEqual(
      nodeDescription({
        configuration: {
          notes: "Imported note",
          notesInFlow: false,
        },
      }),
      ""
    );

    assert.strictEqual(
      nodeDescription({
        configuration: {
          notes: "Visible note",
          notesInFlow: true,
        },
      }),
      "Visible note"
    );
  });
});
