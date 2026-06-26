import { module, test } from "qunit";
import {
  normalizeConnectionsForNodes,
  normalizeNodeConfiguration,
  removeNodesFromGraph,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/editor/graph-utils";

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
        { clientId: "done", type: "action:topic_tags" },
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
        { clientId: "done", type: "action:topic_tags" },
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

  test("can remove nodes without reconnecting neighbours", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "action", type: "action:set_fields" },
        { clientId: "done", type: "action:topic_tags" },
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
      ["action"],
      { reconnect: false }
    );

    assert.deepEqual(normalizeGraph(graph), {
      nodes: [
        { clientId: "done", type: "action:topic_tags" },
        { clientId: "trigger", type: "trigger:manual" },
      ],
      connections: [],
    });
  });

  test("removing a loop node keeps the former body node standalone and reconnects the done path", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "loop", type: "flow:loop_over_items" },
        { clientId: "body", type: "action:set_fields" },
        { clientId: "done", type: "action:topic_tags" },
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
        { clientId: "done", type: "action:topic_tags" },
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

  test("removing a loop node handles index-only loop connections", function (assert) {
    const graph = removeNodesFromGraph(
      [
        { clientId: "trigger", type: "trigger:manual" },
        { clientId: "loop", type: "flow:loop_over_items" },
        { clientId: "body", type: "action:set_fields" },
        { clientId: "done", type: "action:topic_tags" },
      ],
      [
        {
          sourceClientId: "trigger",
          sourceOutputIndex: 0,
          targetClientId: "loop",
          targetInputIndex: 0,
        },
        {
          sourceClientId: "loop",
          sourceOutputIndex: 1,
          targetClientId: "body",
          targetInputIndex: 0,
        },
        {
          sourceClientId: "body",
          sourceOutputIndex: 0,
          targetClientId: "loop",
          targetInputIndex: 0,
        },
        {
          sourceClientId: "loop",
          sourceOutputIndex: 0,
          targetClientId: "done",
          targetInputIndex: 0,
        },
      ],
      ["loop"]
    );

    assert.deepEqual(normalizeGraph(graph), {
      nodes: [
        { clientId: "body", type: "action:set_fields" },
        { clientId: "done", type: "action:topic_tags" },
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
        { clientId: "loop", type: "flow:loop_over_items" },
        { clientId: "body", type: "action:set_fields" },
        { clientId: "done", type: "action:topic_tags" },
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
        { clientId: "done", type: "action:topic_tags" },
        { clientId: "loop", type: "flow:loop_over_items" },
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
        { clientId: "loop", type: "flow:loop_over_items" },
        { clientId: "branch", type: "condition:if" },
        { clientId: "true_body", type: "action:set_fields" },
        { clientId: "false_body", type: "action:topic_tags" },
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
        { clientId: "false_body", type: "action:topic_tags" },
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
        { clientId: "loop", type: "flow:loop_over_items" },
        { clientId: "body_1", type: "action:set_fields" },
        { clientId: "body_2", type: "action:topic_tags" },
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
        { clientId: "body_2", type: "action:topic_tags" },
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

  test("normalizes indexed target inputs as hidden indexes", function (assert) {
    const indexedInputNodeType = {
      identifier: "flow:indexed_input",
      inputs: [
        {
          key: "main",
          multiple: true,
        },
      ],
    };
    const nodes = [
      {
        clientId: "indexed",
        type: "flow:indexed_input",
      },
    ];
    const nodeTypeForNode = () => indexedInputNodeType;
    const connections = [
      {
        sourceClientId: "a",
        sourceOutput: "main",
        targetClientId: "indexed",
        targetInput: "main",
      },
      {
        sourceClientId: "b",
        sourceOutput: "main",
        targetClientId: "indexed",
        targetInput: "main",
      },
      {
        sourceClientId: "c",
        sourceOutput: "main",
        targetClientId: "indexed",
        targetInput: "main",
      },
    ];

    assert.deepEqual(
      normalizeConnectionsForNodes(connections, nodes, nodeTypeForNode).map(
        (connection) => ({
          targetInput: connection.targetInput,
          targetInputIndex: connection.targetInputIndex,
        })
      ),
      [
        { targetInput: "main", targetInputIndex: 0 },
        { targetInput: "main", targetInputIndex: 1 },
        { targetInput: "main", targetInputIndex: 2 },
      ]
    );

    assert.deepEqual(
      normalizeConnectionsForNodes(
        [
          {
            sourceClientId: "a",
            sourceOutput: "main",
            targetClientId: "indexed",
            targetInput: "main",
          },
          {
            sourceClientId: "b",
            sourceOutput: "main",
            targetClientId: "indexed",
            targetInput: "main",
          },
        ],
        nodes,
        nodeTypeForNode
      ).map((connection) => ({
        targetInput: connection.targetInput,
        targetInputIndex: connection.targetInputIndex,
      })),
      [
        { targetInput: "main", targetInputIndex: 0 },
        { targetInput: "main", targetInputIndex: 1 },
      ]
    );
    assert.deepEqual(
      normalizeConnectionsForNodes(
        [
          {
            sourceClientId: "a",
            sourceOutput: "main",
            targetClientId: "indexed",
            targetInputIndex: 1,
          },
          {
            sourceClientId: "b",
            sourceOutput: "main",
            targetClientId: "indexed",
            targetInput: "main",
          },
        ],
        nodes,
        nodeTypeForNode
      ).map((connection) => ({
        targetInput: connection.targetInput,
        targetInputIndex: connection.targetInputIndex,
      })),
      [
        { targetInput: "main", targetInputIndex: 1 },
        { targetInput: "main", targetInputIndex: 0 },
      ]
    );
  });

  test("normalizes configuration from node type metadata", function (assert) {
    assert.deepEqual(
      normalizeNodeConfiguration(
        {
          type: "flow:no_configuration",
          configuration: {
            mode: "append",
            notes: "Keep this visible on the canvas",
            notesInFlow: true,
          },
        },
        {
          identifier: "flow:no_configuration",
          properties: {},
          credentials: [],
        }
      ),
      {
        type: "flow:no_configuration",
        configuration: {
          notes: "Keep this visible on the canvas",
          notesInFlow: true,
        },
      }
    );

    assert.deepEqual(
      normalizeNodeConfiguration(
        {
          type: "action:configured",
          configuration: {
            operation: "list",
          },
        },
        {
          identifier: "action:configured",
          properties: {
            operation: {
              type: "options",
            },
          },
        }
      ),
      {
        type: "action:configured",
        configuration: {
          operation: "list",
        },
      }
    );
  });
});
