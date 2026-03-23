import { module, test } from "qunit";
import {
  buildWorkflowGraphIndex,
  getConnectionKind,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/rete-graph-index";

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
      node("loop", "core:loop_over_items"),
      node("branch", "condition:if"),
      node("true_body", "action:set_fields"),
      node("false_body", "action:append_tags"),
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

    assert.deepEqual([...graphIndex.getLoopBodyNodeIds("loop")].sort(), [
      "branch",
      "false_body",
      "true_body",
    ]);
    assert.strictEqual(graphIndex.getLoopOwner("branch"), "loop");
    assert.strictEqual(graphIndex.getLoopOwner("true_body"), "loop");
    assert.strictEqual(graphIndex.getLoopOwner("false_body"), "loop");

    assert.deepEqual(
      getConnectionKind(graphIndex, connection("loop", "loop", "branch")),
      { isLoopBody: true, isLoopReturn: false, isLoopChain: false }
    );
    assert.deepEqual(
      getConnectionKind(graphIndex, connection("branch", "true", "true_body")),
      { isLoopBody: false, isLoopReturn: false, isLoopChain: true }
    );
    assert.deepEqual(
      getConnectionKind(graphIndex, connection("true_body", "main", "loop")),
      { isLoopBody: false, isLoopReturn: true, isLoopChain: false }
    );
    assert.deepEqual(
      getConnectionKind(graphIndex, connection("loop", "done", "done")),
      { isLoopBody: false, isLoopReturn: false, isLoopChain: false }
    );
  });

  test("ignores the loop self-connection placeholder when indexing loop bodies", function (assert) {
    const graphIndex = buildWorkflowGraphIndex(
      [node("loop", "core:loop_over_items")],
      [connection("loop", "loop", "loop")]
    );

    assert.deepEqual([...graphIndex.getLoopBodyNodeIds("loop")], []);
    assert.deepEqual(
      getConnectionKind(graphIndex, connection("loop", "loop", "loop")),
      { isLoopBody: false, isLoopReturn: false, isLoopChain: false }
    );
  });
});
