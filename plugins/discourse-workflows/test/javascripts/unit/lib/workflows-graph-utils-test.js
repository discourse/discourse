import { module, test } from "qunit";
import {
  normalizeConnectionsForNodes,
  normalizeMergeConfiguration,
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

  test("normalizes merge target inputs for the selected mode", function (assert) {
    const connections = [
      {
        sourceClientId: "a",
        sourceOutput: "main",
        targetClientId: "merge",
        targetInput: "main",
      },
      {
        sourceClientId: "b",
        sourceOutput: "main",
        targetClientId: "merge",
        targetInput: "main",
      },
      {
        sourceClientId: "c",
        sourceOutput: "main",
        targetClientId: "merge",
        targetInput: "main",
      },
    ];

    assert.deepEqual(
      normalizeConnectionsForNodes(connections, [
        {
          clientId: "merge",
          type: "flow:merge",
          configuration: { mode: "combine" },
        },
      ]).map((connection) => connection.targetInput),
      ["input_1", "input_2"]
    );

    assert.deepEqual(
      normalizeConnectionsForNodes(
        [
          {
            sourceClientId: "a",
            sourceOutput: "main",
            targetClientId: "merge",
            targetInput: "main",
          },
          {
            sourceClientId: "b",
            sourceOutput: "main",
            targetClientId: "merge",
            targetInput: "main",
          },
        ],
        [
          {
            clientId: "merge",
            type: "flow:merge",
            configuration: { mode: "append" },
          },
        ]
      ).map((connection) => connection.targetInput),
      ["input_1", "input_2"]
    );
    assert.deepEqual(
      normalizeConnectionsForNodes(
        [
          {
            sourceClientId: "a",
            sourceOutput: "main",
            targetClientId: "merge",
            targetInputIndex: 1,
          },
          {
            sourceClientId: "b",
            sourceOutput: "main",
            targetClientId: "merge",
            targetInput: "main",
          },
        ],
        [
          {
            clientId: "merge",
            type: "flow:merge",
            configuration: { mode: "append" },
          },
        ]
      ).map((connection) => connection.targetInputIndex),
      [1, 0]
    );
  });

  test("normalizes merge configuration to the selected mode", function (assert) {
    assert.deepEqual(
      normalizeMergeConfiguration({
        mode: "choose_branch",
        use_data_of_input: "input_2",
        combine_by: "matching_fields",
        fields_to_match: [{ field_1: "id", field_2: "id" }],
      }),
      {
        mode: "choose_branch",
        use_data_of_input: "input_2",
        use_data_of_input_index: 1,
        choose_output: "specified_input",
      }
    );

    assert.deepEqual(
      normalizeMergeConfiguration({
        mode: "append",
        use_data_of_input: "input_2",
      }),
      { mode: "append", number_inputs: 2 }
    );
  });
});
