import {
  buildOutgoingIndex,
  collectLoopBodyNodeIds,
  LOOP_NODE_TYPE,
  LOOP_OUTPUT,
  normalizeSourceOutput,
} from "../../../lib/workflows/graph-constants";

export {
  graphConnectionKey,
  normalizeSourceOutput,
} from "../../../lib/workflows/graph-constants";

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

  const loopBodyNodeIdsByLoopId = new Map();
  const loopOwnerByNodeId = new Map();

  for (const loopNodeId of loopNodeIds) {
    const bodyNodeIds = collectLoopBodyNodeIds(loopNodeId, outgoingBySource);

    loopBodyNodeIdsByLoopId.set(loopNodeId, bodyNodeIds);

    for (const nodeId of bodyNodeIds) {
      if (!loopOwnerByNodeId.has(nodeId)) {
        loopOwnerByNodeId.set(nodeId, loopNodeId);
      }
    }
  }

  return {
    loopNodeIds,
    loopOwnerByNodeId,
    loopBodyNodeIdsByLoopId,
    isLoopNode(nodeId) {
      return loopNodeIds.has(nodeId);
    },
    getLoopOwner(nodeId) {
      return loopOwnerByNodeId.get(nodeId) || null;
    },
    getLoopBodyNodeIds(loopNodeId) {
      return loopBodyNodeIdsByLoopId.get(loopNodeId) || new Set();
    },
    isLoopBodyNode(nodeId, loopNodeId) {
      return this.getLoopBodyNodeIds(loopNodeId).has(nodeId);
    },
  };
}

export function getConnectionKind(graphIndex, connection) {
  const sourceOutput = normalizeSourceOutput(connection.sourceOutput);
  const isLoopBody =
    sourceOutput === LOOP_OUTPUT && connection.source !== connection.target;

  if (isLoopBody) {
    return { isLoopBody, isLoopReturn: false, isLoopChain: false };
  }

  const isLoopReturn =
    connection.source !== connection.target &&
    graphIndex.isLoopNode(connection.target) &&
    graphIndex.isLoopBodyNode(connection.source, connection.target);

  if (isLoopReturn) {
    return { isLoopBody: false, isLoopReturn, isLoopChain: false };
  }

  const sourceLoopOwner = graphIndex.getLoopOwner(connection.source);
  const isLoopChain =
    !!sourceLoopOwner &&
    sourceLoopOwner === graphIndex.getLoopOwner(connection.target);

  return { isLoopBody: false, isLoopReturn: false, isLoopChain };
}
