import {
  buildOutgoingIndex,
  collectLoopBodyNodeIds,
  graphConnectionKey,
  LOOP_NODE_TYPE,
  normalizeSourceOutput,
} from "../../../lib/workflows/graph-constants";

export {
  buildOutgoingIndex,
  LOOP_NODE_TYPE,
} from "../../../lib/workflows/graph-constants";

function clientConnectionKey(connection) {
  return graphConnectionKey({
    source: connection.sourceClientId,
    sourceOutput: connection.sourceOutput,
    target: connection.targetClientId,
  });
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
      connection.sourceClientId === loopNodeClientId &&
      connection.sourceOutput === "done" &&
      connection.targetClientId !== loopNodeClientId &&
      !idsToRemove.has(connection.targetClientId)
  );

  return incoming.flatMap((src) =>
    doneOutgoing.map((tgt) => ({
      sourceClientId: src.sourceClientId,
      targetClientId: tgt.targetClientId,
      sourceOutput: normalizeSourceOutput(src.sourceOutput),
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
