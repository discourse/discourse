export const DEFAULT_OUTPUT = "main";
export const LOOP_NODE_TYPE = "flow:loop_over_items";
export const LOOP_OUTPUT = "loop";

export function normalizeSourceOutput(sourceOutput) {
  return sourceOutput || DEFAULT_OUTPUT;
}

export function graphConnectionKey({ source, sourceOutput, target }) {
  return `${source}::${normalizeSourceOutput(sourceOutput)}::${target}`;
}

export function buildOutgoingIndex(connections, sourceKey = "source") {
  const index = new Map();

  for (const connection of connections) {
    const key = connection[sourceKey];
    const list = index.get(key);
    if (list) {
      list.push(connection);
    } else {
      index.set(key, [connection]);
    }
  }

  return index;
}

export function collectLoopBodyNodeIds(
  loopNodeId,
  outgoingBySource,
  { targetKey = "target", outputKey = "sourceOutput" } = {}
) {
  const bodyNodeIds = new Set();
  const stack = [];

  for (const connection of outgoingBySource.get(loopNodeId) || []) {
    if (
      normalizeSourceOutput(connection[outputKey]) === LOOP_OUTPUT &&
      connection[targetKey] !== loopNodeId
    ) {
      stack.push(connection[targetKey]);
    }
  }

  while (stack.length > 0) {
    const nodeId = stack.pop();

    if (nodeId === loopNodeId || bodyNodeIds.has(nodeId)) {
      continue;
    }

    bodyNodeIds.add(nodeId);

    for (const connection of outgoingBySource.get(nodeId) || []) {
      if (connection[targetKey] !== loopNodeId) {
        stack.push(connection[targetKey]);
      }
    }
  }

  return bodyNodeIds;
}

export function buildWorkflowGraphIndex(nodes, connections) {
  const loopNodeIds = new Set(
    nodes.filter((node) => node.type === LOOP_NODE_TYPE).map((node) => node.id)
  );
  const outgoingBySource = buildOutgoingIndex(
    connections.map((c) => ({
      ...c,
      sourceOutput: normalizeSourceOutput(c.sourceOutput),
    }))
  );

  const loopOwnerByNodeId = new Map();

  for (const loopNodeId of loopNodeIds) {
    const bodyNodeIds = collectLoopBodyNodeIds(loopNodeId, outgoingBySource);
    for (const nodeId of bodyNodeIds) {
      if (!loopOwnerByNodeId.has(nodeId)) {
        loopOwnerByNodeId.set(nodeId, loopNodeId);
      }
    }
  }

  return { loopNodeIds, loopOwnerByNodeId };
}

export function getConnectionKind(graphIndex, connection) {
  const sourceOutput = normalizeSourceOutput(connection.sourceOutput);

  if (sourceOutput === LOOP_OUTPUT && connection.source !== connection.target) {
    return "loopBody";
  }

  if (
    connection.source !== connection.target &&
    graphIndex.loopNodeIds.has(connection.target) &&
    graphIndex.loopOwnerByNodeId.get(connection.source) === connection.target
  ) {
    return "loopReturn";
  }

  const sourceLoopOwner = graphIndex.loopOwnerByNodeId.get(connection.source);
  if (
    sourceLoopOwner &&
    sourceLoopOwner === graphIndex.loopOwnerByNodeId.get(connection.target)
  ) {
    return "loopChain";
  }

  return null;
}

export function buildConnectedOutputsIndex(connections) {
  const connected = new Map();
  for (const conn of connections) {
    const output = normalizeSourceOutput(conn.sourceOutput);
    if (!connected.has(conn.source)) {
      connected.set(conn.source, new Set());
    }
    connected.get(conn.source).add(output);
  }
  return connected;
}
