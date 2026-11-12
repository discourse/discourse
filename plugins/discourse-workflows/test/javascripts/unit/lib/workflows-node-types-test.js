import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ComboBoxField from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/combo-box";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";
import {
  nodeTypeHasConfigurationFields,
  nodeTypeI18nPrefix,
  nodeTypeI18nScope,
  nodeTypeInputLabel,
  nodeTypeInputs,
  nodeTypeInputUsesConnectionIndexes,
  nodeTypeOperationLabel,
  nodeTypeOutputKeys,
  nodeTypePaletteGroup,
  nodeTypePortLabel,
  nodeTypePrimaryOutputKey,
  nodeTypeRunScopeLabelKey,
  nodeTypeVersion,
  resolveNodeTypeVersion,
} from "discourse/plugins/discourse-workflows/admin/lib/workflows/node-types";

module("Unit | Utility | workflows node types", function () {
  test("reads i18n metadata from the descriptor ui", function (assert) {
    const nodeType = {
      identifier: "action:ai_agent",
      ui: {
        i18n_prefix: "discourse_ai.discourse_workflows",
        i18n_scope: "ai_agent",
      },
    };

    assert.strictEqual(
      nodeTypeI18nPrefix(nodeType),
      "discourse_ai.discourse_workflows"
    );
    assert.strictEqual(nodeTypeI18nScope(nodeType), "ai_agent");
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
      identifier: "flow:loop_over_items",
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

  test("resolves a full node definition for a saved type version", function (assert) {
    const nodeType = {
      identifier: "action:versioned",
      latest: {
        identifier: "action:versioned",
        version: "2.0",
        outputs: [{ key: "new", primary: true }],
      },
      versions: {
        "1.0": {
          identifier: "action:versioned",
          version: "1.0",
          outputs: [{ key: "old", primary: true }],
        },
        "2.0": {
          identifier: "action:versioned",
          version: "2.0",
          outputs: [{ key: "new", primary: true }],
        },
      },
    };

    assert.strictEqual(resolveNodeTypeVersion(nodeType, "1.0").version, "1.0");
    assert.strictEqual(nodeTypeVersion(nodeType), "2.0");
    assert.deepEqual(nodeTypeOutputKeys(nodeType, { typeVersion: "1.0" }), [
      "old",
    ]);
    assert.deepEqual(nodeTypeOutputKeys(nodeType), ["new"]);
    assert.strictEqual(
      resolveNodeTypeVersion(nodeType, "3.0"),
      null,
      "an unregistered version does not fall back to latest"
    );
    assert.deepEqual(
      nodeTypeOutputKeys(nodeType, {}),
      ["old"],
      "a node without a typeVersion uses the default version, not latest"
    );
  });

  test("detects configurable node type fields from metadata", function (assert) {
    assert.false(
      nodeTypeHasConfigurationFields({
        identifier: "flow:no_configuration",
        properties: {},
        credentials: [],
      })
    );
    assert.true(
      nodeTypeHasConfigurationFields({
        identifier: "action:configured",
        properties: {
          operation: {
            type: "options",
          },
        },
      })
    );
    assert.true(nodeTypeHasConfigurationFields("action:unknown"));
  });

  test("uses the merge node type input socket", function (assert) {
    const mergeNodeType = {
      identifier: "flow:merge",
      inputs: [
        {
          key: "main",
          display_name: "Input",
          required: false,
          multiple: true,
        },
      ],
    };

    const inputs = nodeTypeInputs(mergeNodeType, { configuration: {} });
    assert.deepEqual(
      inputs.map((input) => input.key),
      ["main"]
    );
    assert.true(inputs[0].multiple);
    assert.true(nodeTypeInputUsesConnectionIndexes(mergeNodeType, "main"));
    assert.strictEqual(
      nodeTypeInputLabel(mergeNodeType, "main", {
        configuration: {},
      }),
      "Input"
    );
  });

  test("does not index loop node connections", function (assert) {
    const loopNodeType = {
      identifier: "flow:loop_over_items",
      inputs: [
        {
          key: "main",
          multiple: true,
        },
      ],
    };

    assert.false(nodeTypeInputUsesConnectionIndexes(loopNodeType, "main"));
  });

  test("resolves run scope labels from capabilities", function (assert) {
    const nodeType = {
      identifier: "action:code",
      description: {
        capabilities: {
          run_scope: {
            parameter: "mode",
            values: {
              runOnceForEachItem: "per_item",
              runOnceForAllItems: "all_items",
            },
          },
        },
      },
      properties: {
        mode: {
          default: "runOnceForAllItems",
        },
      },
    };

    assert.strictEqual(
      nodeTypeRunScopeLabelKey(nodeType, { configuration: {} }),
      "discourse_workflows.run_scope.all_items"
    );
    assert.strictEqual(
      nodeTypeRunScopeLabelKey(nodeType, {
        configuration: { mode: "runOnceForEachItem" },
      }),
      "discourse_workflows.run_scope.per_item"
    );
    assert.strictEqual(
      nodeTypeRunScopeLabelKey(nodeType, {
        configuration: { mode: "append" },
      }),
      null
    );
    assert.strictEqual(
      nodeTypeRunScopeLabelKey({
        identifier: "condition:if",
        capabilities: { run_scope: "per_item" },
      }),
      "discourse_workflows.run_scope.per_item"
    );
    assert.strictEqual(
      nodeTypeRunScopeLabelKey({
        identifier: "action:sort",
        capabilities: { run_scope: "all_items" },
      }),
      "discourse_workflows.run_scope.all_items"
    );
  });
});

module("Unit | Service | workflows-node-types", function (hooks) {
  setupTest(hooks);

  test("buildNodeParameterOptionsPayload includes current node, parameters, credentials, and execution context", function (assert) {
    const service = this.owner.lookup("service:workflows-node-types");
    const node = {
      clientId: "node-1",
      name: "Group",
      type: "action:group",
      typeVersion: "1.0",
    };
    const upstreamNode = {
      clientId: "node-0",
      name: "Upstream",
      type: "trigger:topic",
    };
    const runData = {
      Upstream: [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { username: "sam" } }],
              item_count: 1,
            },
          ],
        },
      ],
    };

    const session = new WorkflowEditorSession({
      workflowId: 7,
      lastExecutionRunData: runData,
    });
    session.setEditingContext(
      node,
      [upstreamNode, node],
      [{ sourceClientId: "node-0", targetClientId: "node-1" }]
    );

    const payload = service.buildNodeParameterOptionsPayload({
      identifier: "action:group",
      typeVersion: "1.0",
      methodName: "groups",
      ...session.nodeParameterOptionsContext({
        path: "group_id",
        currentNodeParameters: { operation: "get" },
        credentials: { auth: { id: "12", credential_type: "basic_auth" } },
        filter: "staff",
      }),
    });

    assert.deepEqual(payload.currentNodeParameters, { operation: "get" });
    assert.deepEqual(payload.credentials, {
      auth: { id: "12", credential_type: "basic_auth" },
    });
    assert.deepEqual(payload.nodeTypeAndVersion, {
      name: "action:group",
      version: "1.0",
    });
    assert.deepEqual(payload.node, {
      id: "node-1",
      name: "Group",
      type: "action:group",
      typeVersion: "1.0",
    });
    assert.strictEqual(payload.path, "group_id");
    assert.strictEqual(payload.methodName, "groups");
    assert.strictEqual(payload.workflowId, 7);
    assert.strictEqual(payload.filter, "staff");
    assert.deepEqual(payload.inputContext, {
      available: false,
      reason: "No input execution preview is available for this node",
    });
    assert.deepEqual(payload.executionContext, {
      last_node_outputs: runData,
    });
  });

  test("input context uses recorded input source keys when output indexes are not stored", function (assert) {
    const upstreamNode = {
      clientId: "node-0",
      name: "Branch",
      type: "condition:if",
    };
    const node = {
      clientId: "node-1",
      name: "Log",
      type: "action:log",
      typeVersion: "1.0",
    };
    const rejectedInput = [{ json: { matched: false } }];

    const session = new WorkflowEditorSession({
      workflowId: 7,
      lastExecutionRunData: {
        Branch: [
          {
            status: "success",
            outputs: [
              {
                index: 0,
                items: [{ json: { matched: true } }],
                item_count: 1,
              },
              {
                index: 1,
                items: rejectedInput,
                item_count: 1,
              },
            ],
          },
        ],
        Log: [
          {
            status: "success",
            inputs: [
              {
                index: 0,
                items: rejectedInput,
                item_count: 1,
                source: { node_name: "Branch", output_index: 1 },
              },
            ],
          },
        ],
      },
    });
    session.setEditingContext(
      node,
      [upstreamNode, node],
      [
        {
          sourceClientId: "node-0",
          sourceOutput: "false",
          targetClientId: "node-1",
        },
      ]
    );

    assert.deepEqual(session.inputContextForNode(node), {
      available: true,
      item: rejectedInput[0],
      items: rejectedInput,
      source_node_outputs: { "node-0": rejectedInput },
    });
  });

  test("input context uses current node inputs when upstream output differs", function (assert) {
    const upstreamNode = {
      clientId: "node-0",
      name: "Logger",
      type: "action:log",
    };
    const node = {
      clientId: "node-1",
      name: "After log",
      type: "action:group",
      typeVersion: "1.0",
    };
    const upstreamOutput = [];
    const currentInput = [{ json: { username: "sam" } }];

    const session = new WorkflowEditorSession({
      workflowId: 7,
      lastExecutionRunData: {
        Logger: [
          {
            status: "success",
            outputs: [{ index: 0, items: upstreamOutput, item_count: 0 }],
          },
        ],
        "After log": [
          {
            status: "success",
            inputs: [
              {
                index: 0,
                items: currentInput,
                item_count: currentInput.length,
                source: { node_name: "Logger", output_index: 0 },
              },
            ],
          },
        ],
      },
    });
    session.setEditingContext(
      node,
      [upstreamNode, node],
      [{ sourceClientId: "node-0", targetClientId: "node-1" }]
    );

    assert.deepEqual(session.inputContextForNode(node), {
      available: true,
      item: currentInput[0],
      items: currentInput,
      source_node_outputs: { "node-0": currentInput },
    });
  });

  test("input context ignores recorded inputs from another source", function (assert) {
    const upstreamNode = {
      clientId: "post-moved",
      name: "Post moved",
      type: "trigger:post_moved",
    };
    const node = {
      clientId: "log",
      name: "Log",
      type: "action:log",
      typeVersion: "1.0",
    };
    const staleInput = [{ json: { reviewable: { id: 1 } } }];

    const session = new WorkflowEditorSession({
      workflowId: 7,
      lastExecutionRunData: {
        Log: [
          {
            node_id: "log",
            node_type: "action:log",
            status: "success",
            inputs: [
              {
                index: 0,
                items: staleInput,
                item_count: staleInput.length,
                source: { node_name: "Approved reviewable", output_index: 0 },
              },
            ],
          },
        ],
      },
    });
    session.setEditingContext(
      node,
      [upstreamNode, node],
      [{ sourceClientId: "post-moved", targetClientId: "log" }]
    );

    assert.deepEqual(session.inputContextForNode(node), {
      available: false,
      reason: "No input execution preview is available for this node",
    });
  });

  test("outputItemsForNode returns the latest empty output", function (assert) {
    const node = { clientId: "node-1", name: "Node 1" };

    const session = new WorkflowEditorSession({
      lastExecutionRunData: {
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
      },
    });

    assert.deepEqual(session.outputItemsForNode(node), []);
  });

  test("outputItemsForNode ignores runs for another node with the same name", function (assert) {
    const node = { clientId: "new-node", name: "Node 1", type: "action:log" };

    const session = new WorkflowEditorSession({
      lastExecutionRunData: {
        "Node 1": [
          {
            node_id: "old-node",
            node_type: "action:log",
            status: "success",
            outputs: [
              { index: 0, items: [{ json: { stale: true } }], item_count: 1 },
            ],
          },
        ],
      },
    });

    assert.strictEqual(session.outputItemsForNode(node), undefined);
  });

  test("dynamic options use full node parameters even inside nested configurators", function (assert) {
    const component = Object.create(ComboBoxField.prototype);

    Object.defineProperty(component, "args", {
      value: {
        fieldName: "nested_group_id",
        configuration: { local: true },
        nodeParameters: { operation: "get", authentication: "basic_auth" },
        credentials: { auth: { id: "12", credential_type: "basic_auth" } },
        node: { clientId: "node-1", type: "action:group" },
      },
    });

    const context = component.remoteOptionsContext("staff");

    assert.deepEqual(context.currentNodeParameters, {
      operation: "get",
      authentication: "basic_auth",
    });
    assert.deepEqual(context.credentials, {
      auth: { id: "12", credential_type: "basic_auth" },
    });
    assert.deepEqual(context.node, {
      clientId: "node-1",
      type: "action:group",
    });
    assert.strictEqual(context.path, "nested_group_id");
    assert.strictEqual(context.filter, "staff");
  });

  test("clearEditingContext preserves workflow execution run data", function (assert) {
    const runData = {
      "node-1": [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { value: 1 } }],
              item_count: 1,
            },
          ],
        },
      ],
    };

    const session = new WorkflowEditorSession({
      workflowId: 7,
      lastExecutionRunData: runData,
    });
    session.setEditingContext(
      { clientId: "node-1", type: "action:code" },
      [{ clientId: "node-1", type: "action:code" }],
      []
    );

    session.clearEditingContext();

    assert.strictEqual(session.editingNode, null);
    assert.strictEqual(session.graphNodes, null);
    assert.strictEqual(session.graphConnections, null);
    assert.strictEqual(session.workflowId, 7);
    assert.strictEqual(session.lastExecutionRunData, runData);
  });

  test("loadNodeParameterOptions posts structured context and caches by context", async function (assert) {
    const requests = [];

    pretender.post(
      "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
      (request) => {
        const body = JSON.parse(request.requestBody);
        requests.push(body);

        return response([
          { id: requests.length, name: body.currentNodeParameters.operation },
        ]);
      }
    );

    const service = this.owner.lookup("service:workflows-node-types");
    const context = {
      path: "group_id",
      currentNodeParameters: { operation: "add" },
      filter: "alp",
      node: { clientId: "node-1", name: "Group" },
    };

    const first = await service.loadNodeParameterOptions(
      "action:group",
      "groups",
      "1.0",
      context
    );
    const second = await service.loadNodeParameterOptions(
      "action:group",
      "groups",
      "1.0",
      context
    );
    const third = await service.loadNodeParameterOptions(
      "action:group",
      "groups",
      "1.0",
      { ...context, currentNodeParameters: { operation: "get" } }
    );

    assert.strictEqual(requests.length, 2);
    assert.deepEqual(second, first);
    assert.deepEqual(requests[0].currentNodeParameters, { operation: "add" });
    assert.strictEqual(requests[0].path, "group_id");
    assert.strictEqual(requests[0].methodName, "groups");
    assert.strictEqual(requests[0].filter, "alp");
    assert.deepEqual(requests[0].nodeTypeAndVersion, {
      name: "action:group",
      version: "1.0",
    });
    assert.deepEqual(requests[0].node, {
      id: "node-1",
      name: "Group",
      type: "action:group",
      typeVersion: "1.0",
    });
    assert.strictEqual(third[0].name, "get");
  });
});
