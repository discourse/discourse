export const DEFAULT_OUTPUT = "main";
export const LOOP_NODE_TYPE = "flow:loop_over_items";
export const LOOP_OUTPUT = "loop";

export function normalizeSourceOutput(sourceOutput) {
  return sourceOutput || DEFAULT_OUTPUT;
}

export function normalizeTargetInput(targetInput) {
  return targetInput || "main";
}

export function portIndexFromKey(value, orderedKeys = null) {
  value = value?.toString() || DEFAULT_OUTPUT;

  const orderedIndex = orderedKeys?.findIndex(
    (key) => key?.toString() === value
  );
  if (orderedIndex >= 0) {
    return orderedIndex;
  }

  if (value === "main" || value === "true" || value === "done") {
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

export function normalizeSourceOutputIndex(
  connection,
  orderedOutputKeys = null
) {
  return (
    connection.sourceOutputIndex ??
    portIndexFromKey(connection.sourceOutput, orderedOutputKeys)
  );
}

export function normalizeTargetInputIndex(connection) {
  return (
    connection.targetInputIndex ?? portIndexFromKey(connection.targetInput)
  );
}

export function nextAvailableTargetInputIndex(
  connections,
  targetClientId,
  ignoredConnection = null
) {
  const used = new Set();

  for (const connection of connections) {
    if (
      connection === ignoredConnection ||
      (ignoredConnection?.id && connection.id === ignoredConnection.id)
    ) {
      continue;
    }

    if ((connection.targetClientId ?? connection.target) !== targetClientId) {
      continue;
    }

    used.add(normalizeTargetInputIndex(connection));
  }

  let index = 0;
  while (used.has(index)) {
    index++;
  }
  return index;
}

export function graphConnectionKey({
  source,
  sourceOutput,
  sourceOutputIndex,
  target,
  targetInput,
  targetInputIndex,
}) {
  const outputIndex =
    sourceOutputIndex ?? portIndexFromKey(normalizeSourceOutput(sourceOutput));
  const inputIndex =
    targetInputIndex ?? portIndexFromKey(normalizeTargetInput(targetInput));
  return `${source}::${outputIndex}::${target}::${inputIndex}`;
}

export function connectionMatchesEndpoint(
  connection,
  {
    sourceClientId,
    sourceOutput,
    sourceOutputIndex,
    targetClientId,
    targetInput = "main",
    targetInputIndex = null,
  }
) {
  return (
    (connection.sourceClientId ?? connection.source) === sourceClientId &&
    normalizeSourceOutputIndex(connection) ===
      (sourceOutputIndex ?? portIndexFromKey(sourceOutput)) &&
    (connection.targetClientId ?? connection.target) === targetClientId &&
    normalizeTargetInputIndex(connection) ===
      (targetInputIndex ?? portIndexFromKey(targetInput))
  );
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
      (normalizeSourceOutput(connection[outputKey]) === LOOP_OUTPUT ||
        normalizeSourceOutputIndex(connection) === 1) &&
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
      sourceOutputIndex: normalizeSourceOutputIndex(c),
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
  const sourceOutputIndex = normalizeSourceOutputIndex(connection);

  if (
    sourceOutputIndex === 1 &&
    graphIndex.loopNodeIds.has(connection.source) &&
    connection.source !== connection.target
  ) {
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
    const output = normalizeSourceOutputIndex(conn);
    if (!connected.has(conn.source)) {
      connected.set(conn.source, new Set());
    }
    connected.get(conn.source).add(output);
  }
  return connected;
}
