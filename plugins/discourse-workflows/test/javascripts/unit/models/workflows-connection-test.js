import { module, test } from "qunit";
import { serializeConnections } from "discourse/plugins/discourse-workflows/admin/models/workflow-connection";
import WorkflowNode from "discourse/plugins/discourse-workflows/admin/models/workflow-node";

// referenced through a variable so `no-proto` does not flag the member access
const PROTO_NAME = "__proto__";

module("Unit | Model | discourse-workflows | workflow-connection", function () {
  test("serializeConnections keeps connections from a node named __proto__", function (assert) {
    const source = WorkflowNode.create({
      clientId: "source",
      type: "trigger:manual",
      name: PROTO_NAME,
    });
    const target = WorkflowNode.create({
      clientId: "target",
      type: "action:post",
      name: "Send post",
    });

    try {
      const serialized = serializeConnections(
        [
          {
            sourceClientId: "source",
            targetClientId: "target",
            connectionType: "main",
            sourceOutputIndex: 0,
            targetInputIndex: 0,
          },
        ],
        [source, target]
      );

      assert.deepEqual(
        Object.keys(serialized),
        [PROTO_NAME],
        "the connection survives serialization"
      );
      assert.deepEqual(serialized[PROTO_NAME], {
        main: [[{ node: "Send post", type: "main", index: 0 }]],
      });
      assert.strictEqual(
        {}.main,
        undefined,
        "Object.prototype is left untouched"
      );
    } finally {
      delete Object.prototype.main;
    }
  });
});
