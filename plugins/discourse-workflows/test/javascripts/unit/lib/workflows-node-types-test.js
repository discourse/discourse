import { module, test } from "qunit";
import {
  nodeTypeOperationLabel,
  nodeTypePaletteGroup,
  nodeTypePortLabel,
  nodeTypePrimaryOutputKey,
  nodeTypePropertyI18nPrefix,
  nodeTypePropertyI18nScope,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/node-types";

module("Unit | Utility | workflows node types", function () {
  test("reads property i18n metadata from the descriptor ui", function (assert) {
    const nodeType = {
      identifier: "action:ai_agent",
      ui: {
        property_i18n_prefix: "discourse_ai.discourse_workflows",
        property_i18n_scope: "ai_agent",
      },
    };

    assert.strictEqual(
      nodeTypePropertyI18nPrefix(nodeType),
      "discourse_ai.discourse_workflows"
    );
    assert.strictEqual(nodeTypePropertyI18nScope(nodeType), "ai_agent");
  });

  test("reads operation labels and palette groups from the descriptor", function (assert) {
    const nodeType = {
      identifier: "action:data_table",
      operations: [
        {
          value: "insert",
          label_key: "discourse_workflows.data_table_node.operations.insert",
        },
      ],
      ui: {
        palette_group: {
          id: "data",
          icon: "table",
          label_key: "discourse_workflows.add_node.categories.data",
          order: 50,
        },
      },
    };

    assert.strictEqual(nodeTypeOperationLabel(nodeType, "insert"), "Insert");
    assert.deepEqual(nodeTypePaletteGroup(nodeType), {
      id: "data",
      icon: "table",
      label_key: "discourse_workflows.add_node.categories.data",
      order: 50,
    });
  });

  test("uses descriptor ports for labels and routing", function (assert) {
    const filterNodeType = {
      identifier: "condition:filter",
      ports: [
        {
          key: "true",
          primary: true,
          label_key: "discourse_workflows.executions.statuses.kept",
        },
        {
          key: "false",
          primary: false,
          label_key: "discourse_workflows.executions.statuses.rejected",
        },
      ],
    };
    const loopNodeType = {
      identifier: "core:loop_over_items",
      ports: [
        {
          key: "done",
          primary: true,
          label_key: "discourse_workflows.branch.done",
        },
        {
          key: "loop",
          primary: false,
          label_key: "discourse_workflows.branch.loop",
        },
      ],
    };

    assert.strictEqual(nodeTypePortLabel(filterNodeType, "true"), "Kept");
    assert.strictEqual(nodeTypePortLabel(filterNodeType, "false"), "Rejected");
    assert.strictEqual(nodeTypePrimaryOutputKey(loopNodeType), "done");
  });
});
