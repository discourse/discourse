export const DEFAULT_OUTPUT = "main";
export const LOOP_NODE_TYPE = "core:loop_over_items";
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
