import { module, test } from "qunit";
import { removeNodesFromGraph } from "discourse/plugins/discourse-workflows/admin/components/workflows/editor/graph-utils";

function sortByKey(items, keyFn) {
  return [...items].sort((a, b) => keyFn(a).localeCompare(keyFn(b)));
}

function normalizeGraph(graph) {
  return {
    nodes: sortByKey(graph.nodes, (node) => node.clientId).map((node) => ({
      clientId: node.clientId,
      type: node.type,
    })),
    connections: sortByKey(
      graph.connections,
      (connection) =>
        `${connection.sourceClientId}::${connection.sourceOutput || "main"}::${connection.targetClientId}`
    ).map((connection) => ({
      sourceClientId: connection.sourceClientId,
      sourceOutput: connection.sourceOutput || "main",
      targetClientId: connection.targetClientId,
    })),
  };
}

module("Unit | Utility | workflows graph utils", function () {
  test("reconnects a regular node with one incoming and one outgoing edge", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "action", type: "action:set_fields" },
        { clientId: "done", type: "action:append_tags" },
      ],
      [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "action",
        },
        {
          sourceClientId: "action",
          sourceOutput: "main",
          targetClientId: "done",
        },
      ],
      ["action"]
    );

    assert.deepEqual(normalizeGraph(graph), {
      nodes: [
        { clientId: "done", type: "action:append_tags" },
        { clientId: "trigger", type: "trigger:manual" },
      ],
      connections: [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "done",
        },
      ],
    });
  });

  test("removing a loop node keeps the former body node standalone and reconnects the done path", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "loop", type: "core:loop_over_items" },
        { clientId: "body", type: "action:set_fields" },
        { clientId: "done", type: "action:append_tags" },
      ],
      [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "body",
        },
        {
          sourceClientId: "body",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "done",
          targetClientId: "done",
        },
      ],
      ["loop"]
    );

    assert.deepEqual(normalizeGraph(graph), {
      nodes: [
        { clientId: "body", type: "action:set_fields" },
        { clientId: "done", type: "action:append_tags" },
        { clientId: "trigger", type: "trigger:manual" },
      ],
      connections: [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "done",
        },
      ],
    });
  });

  test("removing the only loop body preserves the loop self-connection", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "loop", type: "core:loop_over_items" },
        { clientId: "body", type: "action:set_fields" },
        { clientId: "done", type: "action:append_tags" },
      ],
      [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "body",
        },
        {
          sourceClientId: "body",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "done",
          targetClientId: "done",
        },
      ],
      ["body"]
    );

    assert.deepEqual(normalizeGraph(graph), {
      nodes: [
        { clientId: "done", type: "action:append_tags" },
        { clientId: "loop", type: "core:loop_over_items" },
        { clientId: "trigger", type: "trigger:manual" },
      ],
      connections: [
        {
          sourceClientId: "loop",
          sourceOutput: "done",
          targetClientId: "done",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "loop",
        },
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "loop",
        },
      ],
    });
  });

  test("removing a loop node preserves the internal body subgraph", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "loop", type: "core:loop_over_items" },
        { clientId: "branch", type: "condition:if" },
        { clientId: "true_body", type: "action:set_fields" },
        { clientId: "false_body", type: "action:append_tags" },
        { clientId: "done", type: "action:http_request" },
      ],
      [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "branch",
        },
        {
          sourceClientId: "branch",
          sourceOutput: "true",
          targetClientId: "true_body",
        },
        {
          sourceClientId: "branch",
          sourceOutput: "false",
          targetClientId: "false_body",
        },
        {
          sourceClientId: "true_body",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "false_body",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "done",
          targetClientId: "done",
        },
      ],
      ["loop"]
    );

    assert.deepEqual(normalizeGraph(graph), {
      nodes: [
        { clientId: "branch", type: "condition:if" },
        { clientId: "done", type: "action:http_request" },
        { clientId: "false_body", type: "action:append_tags" },
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "true_body", type: "action:set_fields" },
      ],
      connections: [
        {
          sourceClientId: "branch",
          sourceOutput: "false",
          targetClientId: "false_body",
        },
        {
          sourceClientId: "branch",
          sourceOutput: "true",
          targetClientId: "true_body",
        },
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "done",
        },
      ],
    });
  });

  test("bulk loop deletion does not reconnect surviving body nodes to the done path", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "loop", type: "core:loop_over_items" },
        { clientId: "body_1", type: "action:set_fields" },
        { clientId: "body_2", type: "action:append_tags" },
        { clientId: "done", type: "action:http_request" },
      ],
      [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "loop",
          targetClientId: "body_1",
        },
        {
          sourceClientId: "body_1",
          sourceOutput: "main",
          targetClientId: "body_2",
        },
        {
          sourceClientId: "body_2",
          sourceOutput: "main",
          targetClientId: "loop",
        },
        {
          sourceClientId: "loop",
          sourceOutput: "done",
          targetClientId: "done",
        },
      ],
      ["loop", "body_1"]
    );

    assert.deepEqual(normalizeGraph(graph), {
      nodes: [
        { clientId: "body_2", type: "action:append_tags" },
        { clientId: "done", type: "action:http_request" },
        { clientId: "trigger", type: "trigger:manual" },
      ],
      connections: [
        {
          sourceClientId: "trigger",
          sourceOutput: "main",
          targetClientId: "done",
        },
      ],
    });
  });
});
