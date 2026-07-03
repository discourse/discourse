import { module, test } from "qunit";
import {
  ancestorOutputNodes,
  exemplarFromFields,
  inputConnectionsForNode,
  inputFieldPrefixForConnection,
  inputForRun,
  inputSummaryForNode,
  nodeOutputFirstJsonPath,
  nodeOutputItemJsonPath,
  nodeOutputJsonPath,
  nodeOutputLinkedItemJsonPath,
  outputForRun,
  outputSchemaForNode,
  outputSummaryForNode,
  schemaFieldsForItems,
  schemaFieldsForNodeInput,
  schemaFieldsForNodeOutput,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/data-schema";

module("Unit | lib | discourse-workflows | data-schema", function () {
  test("schemaFieldsForItems infers and merges nested JSON fields", function (assert) {
    const fields = schemaFieldsForItems([
      {
        json: {
          title: "Hello",
          count: 1,
          published: true,
          author: { username: "sam" },
        },
      },
      {
        json: {
          count: 2,
          author: { id: 12 },
          tags: ["support"],
        },
      },
    ]);

    assert.deepEqual(
      fields.map((field) => [field.key, field.type, field.id]),
      [
        ["title", "string", "$json.title"],
        ["count", "number", "$json.count"],
        ["published", "boolean", "$json.published"],
        ["author", "object", "$json.author"],
        ["tags", "array", "$json.tags"],
      ]
    );
    assert.deepEqual(
      fields.find((field) => field.key === "author").children.map((f) => f.key),
      ["username", "id"]
    );
    assert.strictEqual(
      fields.find((field) => field.key === "tags").children[0].id,
      "$json.tags[0]"
    );
  });

  test("schemaFieldsForItems uses bracket paths for unsafe keys", function (assert) {
    const fields = schemaFieldsForItems([
      { json: { "topic title": { "post-count": 2 } } },
    ]);

    assert.strictEqual(fields[0].id, '$json["topic title"]');
    assert.strictEqual(
      fields[0].children[0].id,
      '$json["topic title"]["post-count"]'
    );
  });

  test("schemaFieldsForItems preserves null values", function (assert) {
    const fields = schemaFieldsForItems([
      { json: { deleted_at: null, title: null } },
      { json: { title: "Topic" } },
    ]);

    const deletedAt = fields.find((field) => field.key === "deleted_at");
    const title = fields.find((field) => field.key === "title");

    assert.strictEqual(deletedAt.type, "null");
    assert.strictEqual(deletedAt.value, null);
    assert.strictEqual(title.type, "string");
    assert.strictEqual(title.value, "Topic");
    assert.deepEqual(exemplarFromFields(fields), {
      deleted_at: null,
      title: "Topic",
    });
  });

  test("schemaFieldsForNodeOutput uses the latest successful run", function (assert) {
    const runData = {
      "Node 1": [
        {
          status: "success",
          outputs: [
            { index: 0, items: [{ json: { old: true } }], item_count: 1 },
          ],
        },
        {
          status: "success",
          outputs: [
            { index: 0, items: [{ json: { current: true } }], item_count: 1 },
          ],
        },
      ],
    };

    assert.deepEqual(
      schemaFieldsForNodeOutput(runData, "Node 1").map((f) => f.key),
      ["current"]
    );
  });

  test("schemaFieldsForNodeOutput does not reuse older item data after a zero-item run", function (assert) {
    const runData = {
      "Node 1": [
        {
          status: "success",
          outputs: [
            { index: 0, items: [{ json: { stale: true } }], item_count: 1 },
          ],
        },
        {
          status: "success",
          outputs: [{ index: 0, items: [], item_count: 0 }],
        },
      ],
    };

    assert.deepEqual(schemaFieldsForNodeOutput(runData, "Node 1"), []);
    assert.deepEqual(outputSummaryForNode(runData, "Node 1"), {
      outputIndex: 0,
      itemCount: 0,
      truncated: false,
    });
  });

  test("schemaFieldsForNodeOutput ignores runs for another node with the same name", function (assert) {
    const runData = {
      Log: [
        {
          node_id: "old-log",
          node_type: "action:log",
          status: "success",
          outputs: [
            { index: 0, items: [{ json: { stale: true } }], item_count: 1 },
          ],
        },
      ],
    };
    const node = { id: "new-log", name: "Log", type: "action:log" };

    assert.deepEqual(
      schemaFieldsForNodeOutput(runData, "Log", { node }),
      [],
      "does not expose output from a different node id"
    );
    assert.strictEqual(
      outputSummaryForNode(runData, "Log", 0, { node }),
      null,
      "does not expose summary from a different node id"
    );
  });

  test("outputForRun keeps output indexes positional", function (assert) {
    const run = {
      outputs: [{ index: 0, items: [{ json: { primary: true } }] }],
    };

    assert.strictEqual(outputForRun(run, 1), null);
  });

  test("outputSchemaForNode combines output indexes into one preview item", function (assert) {
    const runData = {
      "Node 1": [
        {
          status: "success",
          outputs: [
            { index: 0, items: [{ json: { matched: true } }], item_count: 1 },
            {
              index: 1,
              items: [{ json: { rejected: true } }],
              item_count: 1,
            },
          ],
        },
      ],
    };
    const schema = outputSchemaForNode(runData, "Node 1");

    assert.deepEqual(schema.summary, {
      itemCount: 1,
      truncated: false,
    });
    assert.deepEqual(
      schema.fields.map((field) => field.key),
      ["matched", "rejected"]
    );
  });

  test("schemaFieldsForNodeInput reads recorded node inputs", function (assert) {
    const runData = {
      "Node 1": [
        {
          status: "success",
          inputs: [
            {
              index: 1,
              items: [{ json: { topic: { id: 1 } } }],
              item_count: 2,
              source: { node_name: "Upstream", output_index: 0 },
            },
          ],
        },
      ],
    };

    assert.deepEqual(
      schemaFieldsForNodeInput(runData, "Node 1", { inputIndex: 1 }).map(
        (f) => f.key
      ),
      ["topic"]
    );
    assert.deepEqual(inputSummaryForNode(runData, "Node 1", 1), {
      inputIndex: 1,
      itemCount: 2,
      truncated: false,
    });
    assert.strictEqual(inputForRun(runData["Node 1"][0], 0), null);
  });

  test("schemaFieldsForNodeInput ignores recorded inputs from another source", function (assert) {
    const currentNode = { id: "log", name: "Log", type: "action:log" };
    const sourceNode = {
      id: "post-moved",
      name: "Post moved",
      type: "trigger:post_moved",
    };
    const runData = {
      Log: [
        {
          node_id: "log",
          node_type: "action:log",
          status: "success",
          inputs: [
            {
              index: 0,
              items: [{ json: { reviewable: { id: 1 } } }],
              item_count: 1,
              source: { node_name: "Approved reviewable", output_index: 0 },
            },
          ],
        },
      ],
      "Post moved": [
        {
          node_id: "post-moved",
          node_type: "trigger:post_moved",
          status: "success",
          outputs: [
            { index: 0, items: [{ json: { post: { id: 1 } } }], item_count: 1 },
          ],
        },
      ],
    };

    assert.deepEqual(
      schemaFieldsForNodeInput(runData, "Log", {
        node: currentNode,
        sourceNode,
        outputIndex: 0,
      }),
      [],
      "does not expose input fields from a stale source"
    );
    assert.strictEqual(
      inputSummaryForNode(runData, "Log", 0, {
        node: currentNode,
        sourceNode,
        outputIndex: 0,
      }),
      null,
      "does not expose input summary from a stale source"
    );
  });

  test("schemaFieldsForNodeInput previews connected upstream output before the current node succeeds", function (assert) {
    const currentNode = {
      id: "post",
      name: "Post",
      type: "action:post",
    };
    const sourceNode = {
      id: "template",
      name: "Template",
      type: "action:template",
    };
    const runData = {
      Template: [
        {
          node_id: "template",
          node_type: "action:template",
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { template: "Rendered body" } }],
              item_count: 1,
            },
          ],
        },
      ],
      Post: [
        {
          node_id: "post",
          node_type: "action:post",
          status: "skipped",
          inputs: [
            {
              index: 0,
              items: [{ json: { template: "Rendered body" } }],
              item_count: 1,
              source: null,
            },
          ],
        },
      ],
    };

    assert.deepEqual(
      schemaFieldsForNodeInput(runData, "Post", {
        node: currentNode,
        sourceNode,
        outputIndex: 0,
      }).map((field) => field.key),
      ["template"]
    );
    assert.deepEqual(
      inputSummaryForNode(runData, "Create post", 0, {
        node: currentNode,
        sourceNode,
        outputIndex: 0,
      }),
      {
        inputIndex: 0,
        itemCount: 1,
        truncated: false,
      }
    );
  });

  test("nodeOutputFirstJsonPath escapes node names and output indexes for expressions", function (assert) {
    assert.strictEqual(
      nodeOutputFirstJsonPath('Fetch "quoted" \\ data', { outputIndex: 1 }),
      '$("Fetch \\"quoted\\" \\\\ data").first(1).json'
    );
    assert.strictEqual(
      nodeOutputFirstJsonPath("Fetch data"),
      '$("Fetch data").first().json'
    );
  });

  test("nodeOutputLinkedItemJsonPath escapes node names for expressions", function (assert) {
    assert.strictEqual(
      nodeOutputLinkedItemJsonPath('Fetch "quoted" \\ data'),
      '$("Fetch \\"quoted\\" \\\\ data").item.json'
    );
  });

  test("nodeOutputJsonPath uses the simplest safe output expression", function (assert) {
    const runData = {
      Aggregate: [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { markdown: "summary" } }],
              item_count: 1,
            },
          ],
        },
      ],
      "Per item": [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { name: "Ada" } }, { json: { name: "Grace" } }],
              item_count: 2,
            },
          ],
        },
      ],
    };

    assert.strictEqual(
      nodeOutputJsonPath(runData, "Aggregate"),
      '$("Aggregate").first().json'
    );
    assert.strictEqual(
      nodeOutputJsonPath(runData, "Per item"),
      '$("Per item").item.json'
    );
  });

  test("nodeOutputItemJsonPath builds explicit output and item index references", function (assert) {
    assert.strictEqual(
      nodeOutputItemJsonPath("Second input", { outputIndex: 1 }),
      '$("Second input").all(1)[$itemIndex].json'
    );
  });

  test("inputFieldPrefixForConnection uses $json only for the primary input connection", function (assert) {
    const primaryConnection = {
      sourceClientId: "left",
      targetClientId: "merge",
      targetInputIndex: 0,
    };
    const secondaryConnection = {
      sourceClientId: "right",
      targetClientId: "merge",
      targetInputIndex: 1,
      sourceOutputIndex: 2,
    };

    assert.strictEqual(
      inputFieldPrefixForConnection(
        primaryConnection,
        { name: "Left" },
        { primaryConnection }
      ),
      "$json"
    );
    assert.strictEqual(
      inputFieldPrefixForConnection(
        secondaryConnection,
        { name: "Right" },
        { primaryConnection }
      ),
      '$("Right").all(2)[$itemIndex].json'
    );
  });

  test("outputSummaryForNode exposes item counts and truncation metadata", function (assert) {
    const runData = {
      "Node 1": [
        {
          status: "success",
          outputs: [
            {
              index: 1,
              items: [{ json: { value: 1 } }],
              item_count: 3,
              truncated: true,
            },
          ],
        },
      ],
    };

    assert.deepEqual(outputSummaryForNode(runData, "Node 1", 1), {
      outputIndex: 1,
      itemCount: 3,
      truncated: true,
    });
  });

  test("ancestorOutputNodes follows the upstream chain with output indexes", function (assert) {
    const trigger = { clientId: "trigger" };
    const branch = { clientId: "branch" };
    const current = { clientId: "current" };
    const graph = {
      nodes: [trigger, branch, current],
      connections: [
        { sourceClientId: "trigger", targetClientId: "branch" },
        {
          sourceClientId: "branch",
          targetClientId: "current",
          sourceOutputIndex: 1,
        },
      ],
    };

    assert.deepEqual(ancestorOutputNodes(current, graph), [
      { node: branch, outputIndex: 1 },
      { node: trigger, outputIndex: 0 },
    ]);
  });

  test("inputConnectionsForNode returns all incoming connections by input index", function (assert) {
    const graph = {
      connections: [
        {
          sourceClientId: "right",
          targetClientId: "merge",
          targetInputIndex: 1,
        },
        {
          sourceClientId: "left",
          targetClientId: "merge",
          targetInputIndex: 0,
        },
      ],
    };

    assert.deepEqual(
      inputConnectionsForNode({ clientId: "merge" }, graph).map(
        (connection) => connection.sourceClientId
      ),
      ["left", "right"]
    );
  });
});
