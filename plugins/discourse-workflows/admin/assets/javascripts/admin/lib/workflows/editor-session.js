import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

function compactObject(object) {
  return Object.fromEntries(
    Object.entries(object).filter(([, value]) => value !== undefined)
  );
}

function normalizeNodeForLoadOptions(node, identifier, typeVersion) {
  return compactObject({
    id: node?.clientId || node?.id,
    name: node?.name,
    type: node?.type || identifier,
    typeVersion: node?.typeVersion || typeVersion,
  });
}

function portIndexFromKey(value) {
  value = value?.toString();
  if (!value || value === "main" || value === "true" || value === "done") {
    return 0;
  }

  const inputMatch = value.match(/^input_(\d+)$/);
  if (inputMatch) {
    return parseInt(inputMatch[1], 10) - 1;
  }

  if (value === "false" || value === "loop") {
    return 1;
  }

  return parseInt(value, 10) || 0;
}

function sourceOutputIndexForConnection(connection) {
  return (
    connection.sourceOutputIndex ?? portIndexFromKey(connection.sourceOutput)
  );
}

function targetInputIndexForConnection(connection) {
  return (
    connection.targetInputIndex ?? portIndexFromKey(connection.targetInput)
  );
}

function latestPortItems(runs, portKey, portIndex) {
  const run = [...(runs || [])]
    .reverse()
    .find(
      (candidate) =>
        candidate.status === "success" &&
        (candidate[portKey] || []).some(
          (port) => port.index === portIndex && Array.isArray(port.items)
        )
    );
  const port = (run?.[portKey] || []).find(
    (candidate) => candidate.index === portIndex
  );
  return port?.items;
}

export default class WorkflowEditorSession {
  @tracked workflowId = null;
  @tracked editingNode = null;
  @tracked graphNodes = null;
  @tracked graphConnections = null;
  @tracked lastExecutionRunData = null;
  @tracked pinData = {};
  @tracked webhookTestListeners = {};

  constructor({
    workflowId = null,
    lastExecutionRunData = null,
    pinData = {},
  } = {}) {
    this.workflowId = workflowId;
    this.lastExecutionRunData = lastExecutionRunData;
    this.pinData = pinData || {};
  }

  setEditingContext(node, nodes, connections) {
    this.editingNode = node;
    this.graphNodes = nodes;
    this.graphConnections = connections;
  }

  clearEditingContext() {
    this.editingNode = null;
    this.graphNodes = null;
    this.graphConnections = null;
  }

  nodeParameterOptionsContext(context = {}) {
    const resolvedNode = context.node || this.editingNode;
    const resolvedVersion = context.typeVersion || resolvedNode?.typeVersion;

    return compactObject({
      ...context,
      node: normalizeNodeForLoadOptions(
        resolvedNode,
        context.identifier,
        resolvedVersion
      ),
      workflowId: this.workflowId,
      inputContext:
        context.inputContext === undefined
          ? this.inputContextForNode(resolvedNode)
          : context.inputContext,
      executionContext:
        context.executionContext === undefined
          ? this.executionContextForNode(resolvedNode)
          : context.executionContext,
    });
  }

  inputContextForNode(node = this.editingNode) {
    if (!node || !this.lastExecutionRunData) {
      return {
        available: false,
        reason: "No editor execution preview is available for this node",
      };
    }

    const incomingConnections = (this.graphConnections || []).filter(
      (connection) => connection.targetClientId === node.clientId
    );
    const resolvedInputs = incomingConnections
      .map((connection) => {
        const inputIndex = targetInputIndexForConnection(connection);
        const outputIndex = sourceOutputIndexForConnection(connection);
        const sourceNode = this.nodeForClientId(connection.sourceClientId);
        const currentInput = this.inputItemsForNode(node, inputIndex);

        return {
          sourceNodeId: connection.sourceClientId,
          inputIndex,
          items:
            currentInput ?? this.outputItemsForNode(sourceNode, outputIndex),
        };
      })
      .filter((input) => input.items !== undefined);
    const sourceNodeOutputs = Object.fromEntries(
      resolvedInputs.map((input) => [input.sourceNodeId, input.items])
    );

    if (Object.keys(sourceNodeOutputs).length === 0) {
      return {
        available: false,
        reason:
          "No upstream execution preview output is available for this node",
      };
    }

    const primaryItems = resolvedInputs[0]?.items || [];

    return {
      available: true,
      item: primaryItems[0],
      items: primaryItems,
      source_node_outputs: sourceNodeOutputs,
    };
  }

  executionContextForNode(node = this.editingNode) {
    const currentNodeOutput = node ? this.outputItemsForNode(node) : undefined;

    return compactObject({
      last_node_outputs: this.lastExecutionRunData || {},
      current_node_output: currentNodeOutput,
    });
  }

  pinnedItemsForNode(nodeName) {
    if (!nodeName) {
      return undefined;
    }
    const items = this.pinData?.[nodeName.toString()];
    return Array.isArray(items) && items.length > 0 ? items : undefined;
  }

  isNodePinned(nodeName) {
    return this.pinnedItemsForNode(nodeName) !== undefined;
  }

  async pinNodeData(nodeName, items) {
    if (!this.workflowId) {
      return;
    }
    await ajax(
      `/admin/plugins/discourse-workflows/workflows/${this.workflowId}/pin-data.json`,
      {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({
          node_name: nodeName,
          items,
        }),
      }
    );
    this.pinData = { ...(this.pinData || {}), [nodeName]: items };
  }

  async unpinNodeData(nodeName) {
    if (!this.workflowId) {
      return;
    }
    await ajax(
      `/admin/plugins/discourse-workflows/workflows/${this.workflowId}/pin-data.json`,
      {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ node_name: nodeName }),
      }
    );
    const next = { ...(this.pinData || {}) };
    delete next[nodeName];
    this.pinData = next;
  }

  webhookTestListenerForNode(nodeId) {
    if (!nodeId) {
      return null;
    }

    const listener = this.webhookTestListeners?.[nodeId.toString()];
    if (!listener) {
      return null;
    }

    if (listener.expiresAt && Date.parse(listener.expiresAt) <= Date.now()) {
      return null;
    }

    return listener;
  }

  async startWebhookTestListener(nodeId) {
    if (!this.workflowId || !nodeId) {
      return null;
    }

    const result = await ajax(
      `/admin/plugins/discourse-workflows/workflows/${this.workflowId}/webhook-test-listeners.json`,
      {
        type: "POST",
        data: { trigger_node_id: nodeId },
      }
    );

    const listener = {
      listenerId: result.listener_id,
      testUrl: result.test_url,
      expiresAt: result.expires_at,
    };
    this.webhookTestListeners = {
      ...(this.webhookTestListeners || {}),
      [nodeId]: listener,
    };
    return listener;
  }

  async cancelWebhookTestListener(nodeId) {
    const listener = this.webhookTestListenerForNode(nodeId);
    if (!this.workflowId || !listener) {
      return;
    }

    await ajax(
      `/admin/plugins/discourse-workflows/workflows/${this.workflowId}/webhook-test-listeners/${listener.listenerId}.json`,
      { type: "DELETE" }
    );

    this.clearWebhookTestListener(nodeId);
  }

  clearWebhookTestListener(nodeId) {
    const next = { ...(this.webhookTestListeners || {}) };
    delete next[nodeId];
    this.webhookTestListeners = next;
  }

  outputItemsForNode(node, outputIndex = 0) {
    if (outputIndex === 0) {
      const pinned = this.pinnedItemsForNode(node?.name);
      if (pinned) {
        return pinned;
      }
    }

    const runs = this.lastExecutionRunData?.[node?.name];
    return latestPortItems(runs, "outputs", outputIndex);
  }

  inputItemsForNode(node, inputIndex = 0) {
    const runs = this.lastExecutionRunData?.[node?.name];
    return latestPortItems(runs, "inputs", inputIndex);
  }

  nodeForClientId(clientId) {
    if (!clientId) {
      return null;
    }
    return (this.graphNodes || []).find((n) => n.clientId === clientId) || null;
  }
}
