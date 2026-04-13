import { module, test } from "qunit";
import {
  buildWorkflowGraphIndex,
  getConnectionKind,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/graph-constants";

function node(id, type) {
  return { id, type };
}

function connection(source, sourceOutput, target) {
  return { source, sourceOutput, target };
}

module("Unit | Utility | workflows rete graph index", function () {
  test("classifies branched loop body and loop return connections", function (assert) {
    const nodes = [
      node("trigger", "trigger:manual"),
      node("loop", "flow:loop_over_items"),
      node("branch", "condition:if"),
      node("true_body", "action:set_fields"),
      node("false_body", "action:topic_tags"),
      node("done", "action:http_request"),
    ];
    const connections = [
      connection("trigger", "main", "loop"),
      connection("loop", "loop", "loop"),
      connection("loop", "loop", "branch"),
      connection("branch", "true", "true_body"),
      connection("branch", "false", "false_body"),
      connection("true_body", "main", "loop"),
      connection("false_body", "main", "loop"),
      connection("loop", "done", "done"),
    ];
    const graphIndex = buildWorkflowGraphIndex(nodes, connections);

    assert.strictEqual(graphIndex.loopOwnerByNodeId.get("branch"), "loop");
    assert.strictEqual(graphIndex.loopOwnerByNodeId.get("true_body"), "loop");
    assert.strictEqual(graphIndex.loopOwnerByNodeId.get("false_body"), "loop");

    assert.strictEqual(
      getConnectionKind(graphIndex, connection("loop", "loop", "branch")),
      "loopBody"
    );
    assert.strictEqual(
      getConnectionKind(graphIndex, connection("branch", "true", "true_body")),
      "loopChain"
    );
    assert.strictEqual(
      getConnectionKind(graphIndex, connection("true_body", "main", "loop")),
      "loopReturn"
    );
    assert.strictEqual(
      getConnectionKind(graphIndex, connection("loop", "done", "done")),
      null
    );
  });

  test("ignores the loop self-connection placeholder when indexing loop bodies", function (assert) {
    const graphIndex = buildWorkflowGraphIndex(
      [node("loop", "flow:loop_over_items")],
      [connection("loop", "loop", "loop")]
    );

    assert.strictEqual(graphIndex.loopOwnerByNodeId.size, 0);
    assert.strictEqual(
      getConnectionKind(graphIndex, connection("loop", "loop", "loop")),
      null
    );
  });
});
