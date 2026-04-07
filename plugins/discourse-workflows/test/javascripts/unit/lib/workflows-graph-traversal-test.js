import { module, test } from "qunit";
import {
  findPreviousNode,
  resolveAllAncestors,
  resolveFieldsForNode,
  resolvePreviousOutput,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/graph-traversal";

module("Unit | lib | discourse-workflows | graph-traversal", function () {
  test("findPreviousNode returns the immediate upstream node", function (assert) {
    const trigger = { clientId: "trigger", type: "trigger:manual" };
    const action = { clientId: "action", type: "action:http_request" };
    const graph = {
      nodes: [trigger, action],
      connections: [{ sourceClientId: "trigger", targetClientId: "action" }],
      nodeTypes: [],
    };

    const result = findPreviousNode(action, graph, new Set());
    assert.strictEqual(result, trigger);
  });

  test("findPreviousNode returns null when no incoming connection", function (assert) {
    const trigger = { clientId: "trigger", type: "trigger:manual" };
    const graph = {
      nodes: [trigger],
      connections: [],
      nodeTypes: [],
    };

    const result = findPreviousNode(trigger, graph, new Set());
    assert.strictEqual(result, null);
  });

  test("findPreviousNode returns null on cycle (already visited)", function (assert) {
    const nodeA = { clientId: "a", type: "action:http_request" };
    const nodeB = { clientId: "b", type: "action:http_request" };
    const graph = {
      nodes: [nodeA, nodeB],
      connections: [{ sourceClientId: "a", targetClientId: "b" }],
      nodeTypes: [],
    };

    const visited = new Set(["a"]);
    const result = findPreviousNode(nodeB, graph, visited);
    assert.strictEqual(result, null);
  });

  test("findPreviousNode ignores self-connections", function (assert) {
    const node = { clientId: "loop", type: "action:http_request" };
    const graph = {
      nodes: [node],
      connections: [{ sourceClientId: "loop", targetClientId: "loop" }],
      nodeTypes: [],
    };

    const result = findPreviousNode(node, graph, new Set());
    assert.strictEqual(result, null);
  });

  test("resolveFieldsForNode returns null for condition nodes", function (assert) {
    const node = { clientId: "cond", type: "condition:if", configuration: {} };
    const graph = { nodeTypes: [] };

    const result = resolveFieldsForNode(node, graph);
    assert.strictEqual(result, null);
  });

  test("resolveFieldsForNode falls back to output_schema for trigger nodes", function (assert) {
    const node = {
      clientId: "trigger",
      type: "trigger:manual",
      configuration: {},
    };
    const graph = {
      nodeTypes: [
        {
          identifier: "trigger:manual",
          output_schema: { topic_id: "integer" },
        },
      ],
    };

    const result = resolveFieldsForNode(node, graph);
    assert.deepEqual(result, [
      { key: "topic_id", type: "integer", id: "topic_id" },
    ]);
  });

  test("resolvePreviousOutput walks past nodes with no fields (condition nodes)", function (assert) {
    const trigger = {
      clientId: "trigger",
      type: "trigger:manual",
      configuration: {},
    };
    const condition = {
      clientId: "cond",
      type: "condition:if",
      configuration: {},
    };
    const action = {
      clientId: "action",
      type: "action:http_request",
      configuration: {},
    };
    const graph = {
      nodes: [trigger, condition, action],
      connections: [
        { sourceClientId: "trigger", targetClientId: "cond" },
        { sourceClientId: "cond", targetClientId: "action" },
      ],
      nodeTypes: [
        {
          identifier: "trigger:manual",
          output_schema: { topic_id: "integer" },
        },
      ],
    };

    const result = resolvePreviousOutput(action, graph);
    assert.deepEqual(result, [
      { key: "topic_id", type: "integer", id: "topic_id" },
    ]);
  });

  test("resolvePreviousOutput returns empty array for orphan node", function (assert) {
    const node = {
      clientId: "orphan",
      type: "action:http_request",
      configuration: {},
    };
    const graph = {
      nodes: [node],
      connections: [],
      nodeTypes: [],
    };

    const result = resolvePreviousOutput(node, graph);
    assert.deepEqual(result, []);
  });

  test("resolveAllAncestors collects fields from multiple ancestor nodes", function (assert) {
    const trigger = {
      clientId: "trigger",
      type: "trigger:manual",
      configuration: {},
    };
    const action1 = {
      clientId: "action1",
      type: "action:http_request",
      configuration: {
        output_fields: [{ key: "response", type: "object" }],
      },
    };
    const action2 = {
      clientId: "action2",
      type: "action:http_request",
      configuration: {},
    };
    const graph = {
      nodes: [trigger, action1, action2],
      connections: [
        { sourceClientId: "trigger", targetClientId: "action1" },
        { sourceClientId: "action1", targetClientId: "action2" },
      ],
      nodeTypes: [
        {
          identifier: "trigger:manual",
          output_schema: { topic_id: "integer" },
        },
      ],
    };

    const result = resolveAllAncestors(action2, graph);
    assert.strictEqual(result.length, 2);
    assert.strictEqual(result[0].node, action1);
    assert.deepEqual(result[0].fields, [
      { key: "response", type: "object", id: "response" },
    ]);
    assert.strictEqual(result[1].node, trigger);
    assert.deepEqual(result[1].fields, [
      { key: "topic_id", type: "integer", id: "topic_id" },
    ]);
  });

  test("resolveAllAncestors handles cycle without infinite loop", function (assert) {
    const nodeA = {
      clientId: "a",
      type: "action:http_request",
      configuration: { output_fields: [{ key: "out_a", type: "string" }] },
    };
    const nodeB = {
      clientId: "b",
      type: "action:http_request",
      configuration: {},
    };
    const graph = {
      nodes: [nodeA, nodeB],
      connections: [
        { sourceClientId: "a", targetClientId: "b" },
        { sourceClientId: "b", targetClientId: "a" },
      ],
      nodeTypes: [],
    };

    const result = resolveAllAncestors(nodeB, graph);
    assert.strictEqual(result.length, 1);
    assert.strictEqual(result[0].node, nodeA);
  });
});
