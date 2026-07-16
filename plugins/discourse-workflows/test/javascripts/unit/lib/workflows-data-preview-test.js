import { module, test } from "qunit";
import {
  inputSummaryForNode,
  outputPreviewForNode,
  outputSummaryForNode,
  schemaFieldsForNodeInput,
  schemaFieldsForNodeOutput,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/data-preview";

function declaredType(name) {
  return {
    name,
    versions: {
      "1.0": {
        output_contracts: [
          {
            schema: {
              type: "object",
              properties: { declared: { type: "string" } },
            },
          },
        ],
      },
    },
  };
}

function typedNode(clientId, name, type) {
  return { clientId, name, type, typeVersion: "1.0" };
}

function sampleGraph() {
  const node = typedNode("sample", "Sample", "action:sample");
  const graph = {
    nodes: [node],
    connections: [],
    nodeTypes: [declaredType("action:sample")],
  };
  return { node, graph };
}

function sourceCurrentGraph() {
  const sourceNode = typedNode("source", "Source", "trigger:source");
  const currentNode = typedNode("current", "Current", "action:current");
  const graph = {
    nodes: [sourceNode, currentNode],
    connections: [{ sourceClientId: "source", targetClientId: "current" }],
    nodeTypes: [declaredType("trigger:source")],
  };
  return { sourceNode, currentNode, graph };
}

function successRun(attrs) {
  return { status: "success", ...attrs };
}

function port(index, jsons, extra = {}) {
  return {
    index,
    items: jsons.map((json) => ({ json })),
    item_count: jsons.length,
    ...extra,
  };
}

function keys(fields) {
  return fields.map((field) => field.key);
}

module("Unit | lib | discourse-workflows | data-preview", function () {
  test("schemaFieldsForNodeOutput and outputSummaryForNode use the latest successful run", function (assert) {
    const runData = {
      "Node 1": [
        successRun({ outputs: [port(0, [{ old: true }])] }),
        successRun({
          outputs: [
            port(0, [{ current: true }]),
            port(1, [{ value: 1 }], { item_count: 3, truncated: true }),
          ],
        }),
      ],
    };

    assert.deepEqual(
      keys(schemaFieldsForNodeOutput(runData, "Node 1")),
      ["current"],
      "the latest run wins over older runs"
    );
    assert.deepEqual(
      outputSummaryForNode(runData, "Node 1", 1),
      { outputIndex: 1, itemCount: 3, truncated: true },
      "summaries expose item counts and truncation per output index"
    );

    const emptied = {
      "Node 1": [
        successRun({ outputs: [port(0, [{ stale: true }])] }),
        successRun({ outputs: [port(0, [])] }),
      ],
    };
    assert.deepEqual(
      schemaFieldsForNodeOutput(emptied, "Node 1"),
      [],
      "a zero-item latest run does not reuse older item data"
    );
    assert.deepEqual(outputSummaryForNode(emptied, "Node 1"), {
      outputIndex: 0,
      itemCount: 0,
      truncated: false,
    });
  });

  test("output declarations fill in before a run and after full compaction", function (assert) {
    const { node, graph } = sampleGraph();

    assert.deepEqual(
      keys(schemaFieldsForNodeOutput({}, "Sample", { node, graph })),
      ["declared"],
      "uses declared fields before the first run"
    );
    assert.deepEqual(
      outputPreviewForNode({}, "Sample", { node, graph }),
      {
        summary: null,
        fields: [{ key: "declared", id: "$json.declared", type: "string" }],
      },
      "does not fabricate a declaration summary or items"
    );

    const emptyRun = { Sample: [successRun({ outputs: [port(0, [])] })] };
    assert.deepEqual(
      schemaFieldsForNodeOutput(emptyRun, "Sample", { node, graph }),
      [],
      "a successful empty output takes precedence over the declaration"
    );

    const compacted = {
      Sample: [
        successRun({
          outputs: [port(0, [], { item_count: 24, truncated: true })],
        }),
      ],
    };
    assert.deepEqual(
      keys(schemaFieldsForNodeOutput(compacted, "Sample", { node, graph })),
      ["declared"],
      "recovers declarations when persistence removed every output sample"
    );
    const preview = outputPreviewForNode(compacted, "Sample", { node, graph });
    assert.deepEqual(
      preview.summary,
      { itemCount: 24, truncated: true },
      "keeps the real compacted-run summary alongside declared fields"
    );
    assert.deepEqual(keys(preview.fields), ["declared"]);
  });

  test("schemaFieldsForNodeOutput ignores runs for another node with the same name", function (assert) {
    const runData = {
      Log: [
        successRun({
          node_id: "old-log",
          node_type: "action:log",
          outputs: [port(0, [{ stale: true }])],
        }),
      ],
    };
    const node = { id: "new-log", name: "Log", type: "action:log" };

    assert.deepEqual(schemaFieldsForNodeOutput(runData, "Log", { node }), []);
    assert.strictEqual(outputSummaryForNode(runData, "Log", 0, { node }), null);
  });

  test("outputPreviewForNode combines output indexes into one preview item", function (assert) {
    const runData = {
      "Node 1": [
        successRun({
          outputs: [
            port(0, [{ matched: true }]),
            port(1, [{ rejected: true }]),
          ],
        }),
      ],
    };
    const preview = outputPreviewForNode(runData, "Node 1");

    assert.deepEqual(preview.summary, { itemCount: 1, truncated: false });
    assert.deepEqual(keys(preview.fields), ["matched", "rejected"]);
  });

  test("schemaFieldsForNodeInput reads recorded inputs and previews upstream output", function (assert) {
    const recorded = {
      "Node 1": [
        successRun({
          inputs: [
            port(1, [{ topic: { id: 1 } }], {
              item_count: 2,
              source: { node_name: "Upstream", output_index: 0 },
            }),
          ],
        }),
      ],
    };

    assert.deepEqual(
      keys(schemaFieldsForNodeInput(recorded, "Node 1", { inputIndex: 1 })),
      ["topic"],
      "reads the recorded input port"
    );
    assert.deepEqual(inputSummaryForNode(recorded, "Node 1", 1), {
      inputIndex: 1,
      itemCount: 2,
      truncated: false,
    });

    const currentNode = { id: "post", name: "Post", type: "action:post" };
    const sourceNode = {
      id: "template",
      name: "Template",
      type: "action:template",
    };
    const previewData = {
      Template: [
        successRun({
          node_id: "template",
          node_type: "action:template",
          outputs: [port(0, [{ template: "Rendered body" }])],
        }),
      ],
      Post: [
        {
          node_id: "post",
          node_type: "action:post",
          status: "skipped",
          inputs: [port(0, [{ template: "Rendered body" }], { source: null })],
        },
      ],
    };

    assert.deepEqual(
      keys(
        schemaFieldsForNodeInput(previewData, "Post", {
          node: currentNode,
          sourceNode,
          outputIndex: 0,
        })
      ),
      ["template"],
      "previews the connected upstream output before the current node succeeds"
    );
    assert.deepEqual(
      inputSummaryForNode(previewData, "Post", 0, {
        node: currentNode,
        sourceNode,
        outputIndex: 0,
      }),
      { inputIndex: 0, itemCount: 1, truncated: false }
    );
  });

  test("a successful run with a stale recorded source yields no input preview", function (assert) {
    const { sourceNode, currentNode, graph } = sourceCurrentGraph();
    const runData = {
      Source: [
        successRun({
          node_id: "source",
          node_type: "trigger:source",
          outputs: [port(0, [{ fresh: true }])],
        }),
      ],
      Current: [
        successRun({
          node_id: "current",
          node_type: "action:current",
          inputs: [
            port(0, [{ stale: true }], {
              source: { node_name: "Old source", output_index: 0 },
            }),
          ],
        }),
      ],
    };

    assert.deepEqual(
      schemaFieldsForNodeInput(runData, "Current", {
        node: currentNode,
        sourceNode,
        graph,
        outputIndex: 0,
      }),
      [],
      "does not expose fields from a stale source, a declaration or the source output"
    );
    assert.strictEqual(
      inputSummaryForNode(runData, "Current", 0, {
        node: currentNode,
        sourceNode,
        outputIndex: 0,
      }),
      null,
      "does not expose input summary from a stale source"
    );
  });

  test("schemaFieldsForNodeInput recovers declarations from a fully compacted port", function (assert) {
    const { sourceNode, currentNode, graph } = sourceCurrentGraph();
    const runData = {
      Current: [
        successRun({
          inputs: [
            port(0, [], {
              item_count: 15,
              truncated: true,
              source: { node_name: "Source", output_index: 0 },
            }),
          ],
        }),
      ],
    };

    assert.deepEqual(
      keys(
        schemaFieldsForNodeInput(runData, "Current", {
          node: currentNode,
          sourceNode,
          graph,
        })
      ),
      ["declared"],
      "uses the source declaration when persistence removed every input sample"
    );
    assert.deepEqual(
      inputSummaryForNode(runData, "Current", 0, {
        node: currentNode,
        sourceNode,
      }),
      { inputIndex: 0, itemCount: 15, truncated: true },
      "preserves the actual compacted input count"
    );
  });

  test("schemaFieldsForNodeInput prefers recorded and pinned items over declarations", function (assert) {
    const { sourceNode, currentNode, graph } = sourceCurrentGraph();
    const pinnedItems = [
      { json: { pinned: true } },
      { json: { pinned: false } },
    ];

    assert.deepEqual(
      keys(
        schemaFieldsForNodeInput({}, "Current", {
          node: currentNode,
          sourceNode,
          graph,
          pinnedItems,
        })
      ),
      ["pinned"],
      "pinned source items win before the current node runs"
    );
    assert.deepEqual(
      inputSummaryForNode({}, "Current", 0, {
        node: currentNode,
        sourceNode,
        pinnedItems,
      }),
      { inputIndex: 0, itemCount: 2, truncated: false },
      "pinned items provide a real item summary"
    );

    const runData = {
      Current: [
        successRun({
          inputs: [
            port(0, [{ recorded: true }], {
              source: { node_name: "Source", output_index: 0 },
            }),
          ],
        }),
      ],
    };
    assert.deepEqual(
      keys(
        schemaFieldsForNodeInput(runData, "Current", {
          node: currentNode,
          sourceNode,
          graph,
          pinnedItems,
        })
      ),
      ["recorded"],
      "the current node's recorded input remains authoritative"
    );
  });
});
