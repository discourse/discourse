import {
  normalizeSourceOutputIndex,
  normalizeTargetInputIndex,
} from "./graph-constants.js";

function connectionOrder(left, right) {
  return (
    normalizeTargetInputIndex(left) - normalizeTargetInputIndex(right) ||
    normalizeSourceOutputIndex(left) - normalizeSourceOutputIndex(right) ||
    String(left.sourceClientId).localeCompare(String(right.sourceClientId))
  );
}

export function inputConnectionsForNode(node, graph, visited = new Set()) {
  if (!node) {
    return [];
  }

  return (graph.connections || [])
    .filter(
      (connection) =>
        connection.targetClientId === node.clientId &&
        connection.sourceClientId !== node.clientId &&
        !visited.has(connection.sourceClientId)
    )
    .sort(connectionOrder);
}

export function previousNodeForConnection(connection, graph) {
  if (!connection) {
    return null;
  }

  return (
    (graph.nodes || []).find(
      (node) => node.clientId === connection.sourceClientId
    ) || null
  );
}

export function ancestorOutputNodes(node, graph) {
  const ancestors = [];
  const visitedNodes = new Set(node ? [node.clientId] : []);
  const seenAncestors = new Set();
  const pendingConnections = inputConnectionsForNode(node, graph);

  while (pendingConnections.length) {
    const connection = pendingConnections.shift();
    const previous = previousNodeForConnection(connection, graph);
    if (!previous) {
      continue;
    }

    const outputIndex = normalizeSourceOutputIndex(connection);
    const key = `${previous.clientId}:${outputIndex}`;
    if (!seenAncestors.has(key)) {
      seenAncestors.add(key);
      ancestors.push({
        node: previous,
        outputIndex,
      });
    }

    if (visitedNodes.has(previous.clientId)) {
      continue;
    }
    visitedNodes.add(previous.clientId);
    pendingConnections.push(
      ...inputConnectionsForNode(previous, graph, visitedNodes)
    );
  }

  return ancestors;
}
