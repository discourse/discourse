import {
  buildOutgoingIndex,
  collectLoopBodyNodeIds,
  graphConnectionKey,
  LOOP_NODE_TYPE,
  nextAvailableTargetInputIndex,
  normalizeSourceOutput,
  normalizeSourceOutputIndex,
  normalizeTargetInputIndex,
} from "../../../lib/workflows/graph-constants";
import { NODE_DIRECT_SETTING_KEYS } from "../../../lib/workflows/node-data-shape";
import {
  nodeTypeConnectionIndexedInputKey,
  nodeTypeHasConfigurationFields,
  nodeTypeInputUsesConnectionIndexes,
} from "../../../lib/workflows/node-types";

export {
  buildOutgoingIndex,
  LOOP_NODE_TYPE,
} from "../../../lib/workflows/graph-constants";

function clientConnectionKey(connection) {
  return graphConnectionKey({
    source: connection.sourceClientId,
    sourceOutputIndex: normalizeSourceOutputIndex(connection),
    target: connection.targetClientId,
    targetInputIndex: normalizeTargetInputIndex(connection),
  });
}

function cloneConnectionWithTargetInputIndex(
  connection,
  targetInput,
  targetInputIndex
) {
  return {
    ...connection,
    targetInput,
    targetInputIndex,
  };
}

function hasExplicitTargetInput(connection) {
  return (
    connection.targetInputIndex != null ||
    (connection.targetInput && connection.targetInput !== "main")
  );
}

export function normalizeConnectionsForNodes(
  connections,
  nodes,
  nodeTypeForNode = (node) => node?.type
) {
  const nodeByClientId = new Map(nodes.map((node) => [node.clientId, node]));
  const explicitIndexedConnections = connections.flatMap((connection) => {
    const targetNode = nodeByClientId.get(connection.targetClientId);
    if (
      !inputUsesIndexedConnections(targetNode, nodeTypeForNode) ||
      !hasExplicitTargetInput(connection)
    ) {
      return [];
    }

    return [
      cloneConnectionWithTargetInputIndex(
        connection,
        indexedConnectionInputKey(targetNode, nodeTypeForNode),
        normalizeTargetInputIndex(connection)
      ),
    ];
  });
  const normalizedConnections = [];
  const allocatedIndexedConnections = [...explicitIndexedConnections];

  for (const connection of connections) {
    const targetNode = nodeByClientId.get(connection.targetClientId);
    if (!inputUsesIndexedConnections(targetNode, nodeTypeForNode)) {
      normalizedConnections.push(connection);
      continue;
    }

    const targetInputIndex = normalizeTargetInputIndex(connection);
    const targetInput = indexedConnectionInputKey(targetNode, nodeTypeForNode);

    if (hasExplicitTargetInput(connection)) {
      normalizedConnections.push(
        cloneConnectionWithTargetInputIndex(
          connection,
          targetInput,
          targetInputIndex
        )
      );
      continue;
    }

    const normalizedConnection = cloneConnectionWithTargetInputIndex(
      connection,
      targetInput,
      nextAvailableTargetInputIndex(
        allocatedIndexedConnections,
        connection.targetClientId
      )
    );
    normalizedConnections.push(normalizedConnection);
    allocatedIndexedConnections.push(normalizedConnection);
  }

  return normalizedConnections;
}

function indexedConnectionInputKey(targetNode, nodeTypeForNode) {
  return (
    nodeTypeConnectionIndexedInputKey(
      nodeTypeForNode(targetNode),
      targetNode
    ) || "main"
  );
}

function inputUsesIndexedConnections(targetNode, nodeTypeForNode) {
  if (!targetNode) {
    return false;
  }

  return nodeTypeInputUsesConnectionIndexes(
    nodeTypeForNode(targetNode),
    indexedConnectionInputKey(targetNode, nodeTypeForNode),
    targetNode
  );
}

export function normalizeNodeConfiguration(node, nodeType = node?.type) {
  if (nodeTypeHasConfigurationFields(nodeType, node)) {
    return node;
  }

  return {
    ...node,
    configuration: Object.fromEntries(
      NODE_DIRECT_SETTING_KEYS.filter((key) =>
        Object.hasOwn(node.configuration || {}, key)
      ).map((key) => [key, node.configuration[key]])
    ),
  };
}

function dedupeConnections(connections) {
  const seen = new Set();

  return connections.filter((connection) => {
    if (!connection.sourceClientId || !connection.targetClientId) {
      return false;
    }

    const key = clientConnectionKey(connection);
    if (seen.has(key)) {
      return false;
    }

    seen.add(key);
    return true;
  });
}

function getLoopBodyNodeIds(connections, loopNodeClientId) {
  const outgoing = buildOutgoingIndex(connections, "sourceClientId");
  return collectLoopBodyNodeIds(loopNodeClientId, outgoing, {
    targetKey: "targetClientId",
    outputKey: "sourceOutput",
  });
}

function isLoopDoneConnection(connection, loopNodeClientId) {
  return (
    connection.sourceClientId === loopNodeClientId &&
    (connection.sourceOutput === "done" ||
      normalizeSourceOutputIndex(connection) === 0)
  );
}

function reconnectSingleNode(connections, clientId) {
  const incoming = connections.filter(
    (connection) => connection.targetClientId === clientId
  );
  const outgoing = connections.filter(
    (connection) => connection.sourceClientId === clientId
  );

  if (incoming.length !== 1 || outgoing.length !== 1) {
    return [];
  }

  return [
    {
      sourceClientId: incoming[0].sourceClientId,
      targetClientId: outgoing[0].targetClientId,
      sourceOutput: normalizeSourceOutput(incoming[0].sourceOutput),
      targetInput: outgoing[0].targetInput || "main",
    },
  ];
}

function reconnectLoopNode(connections, loopNodeClientId, idsToRemove) {
  const bodyNodeIds = getLoopBodyNodeIds(connections, loopNodeClientId);
  const incoming = connections.filter(
    (connection) =>
      connection.targetClientId === loopNodeClientId &&
      connection.sourceClientId !== loopNodeClientId &&
      !bodyNodeIds.has(connection.sourceClientId) &&
      !idsToRemove.has(connection.sourceClientId)
  );
  const doneOutgoing = connections.filter(
    (connection) =>
      isLoopDoneConnection(connection, loopNodeClientId) &&
      connection.targetClientId !== loopNodeClientId &&
      !idsToRemove.has(connection.targetClientId)
  );

  return incoming.flatMap((src) =>
    doneOutgoing.map((tgt) => ({
      sourceClientId: src.sourceClientId,
      targetClientId: tgt.targetClientId,
      sourceOutput: normalizeSourceOutput(src.sourceOutput),
      targetInput: tgt.targetInput || "main",
    }))
  );
}

export function removeNodesFromGraph(nodes, connections, clientIds) {
  const idsToRemove = new Set(clientIds);

  if (idsToRemove.size === 0) {
    return { nodes, connections };
  }

  const reconnects = [];

  for (const node of nodes) {
    if (idsToRemove.has(node.clientId) && node.type === LOOP_NODE_TYPE) {
      reconnects.push(
        ...reconnectLoopNode(connections, node.clientId, idsToRemove)
      );
    }
  }

  if (idsToRemove.size === 1) {
    const [clientId] = clientIds;
    const node = nodes.find((n) => n.clientId === clientId);
    if (node?.type !== LOOP_NODE_TYPE) {
      reconnects.push(...reconnectSingleNode(connections, clientId));
    }
  }

  const remainingNodes = nodes.filter(
    (node) => !idsToRemove.has(node.clientId)
  );
  const remainingConnections = connections.filter(
    (connection) =>
      !idsToRemove.has(connection.sourceClientId) &&
      !idsToRemove.has(connection.targetClientId)
  );

  return {
    nodes: remainingNodes,
    connections: dedupeConnections([...remainingConnections, ...reconnects]),
  };
}
