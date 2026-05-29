import {
  buildOutgoingIndex,
  collectLoopBodyNodeIds,
  graphConnectionKey,
  LOOP_NODE_TYPE,
  normalizeSourceOutput,
  normalizeSourceOutputIndex,
  normalizeTargetInputIndex,
  portIndexFromKey,
} from "../../../lib/workflows/graph-constants";

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

function mergeModeFor(node) {
  return node?.configuration?.mode || "append";
}

function cloneConnectionWithTargetInputIndex(connection, targetInputIndex) {
  return {
    ...connection,
    targetInputIndex,
    targetInput: `input_${targetInputIndex + 1}`,
  };
}

function hasExplicitTargetInput(connection) {
  return (
    connection.targetInputIndex != null ||
    (connection.targetInput && connection.targetInput !== "main")
  );
}

function nextUnusedInputIndex(used) {
  let index = 0;
  while (used.has(index)) {
    index++;
  }
  return index;
}

export function normalizeConnectionsForNodes(connections, nodes) {
  const nodeByClientId = new Map(nodes.map((node) => [node.clientId, node]));
  const usedMergeInputs = new Map();

  for (const connection of connections) {
    const targetNode = nodeByClientId.get(connection.targetClientId);
    if (
      targetNode?.type === "flow:merge" &&
      hasExplicitTargetInput(connection)
    ) {
      const used = usedMergeInputs.get(connection.targetClientId) || new Set();
      used.add(normalizeTargetInputIndex(connection));
      usedMergeInputs.set(connection.targetClientId, used);
    }
  }

  return connections.flatMap((connection) => {
    const targetNode = nodeByClientId.get(connection.targetClientId);
    if (targetNode?.type !== "flow:merge") {
      return [connection];
    }

    const mode = mergeModeFor(targetNode);
    const targetInputIndex = normalizeTargetInputIndex(connection);

    if (mode === "append") {
      if (!hasExplicitTargetInput(connection)) {
        const used =
          usedMergeInputs.get(connection.targetClientId) || new Set();
        const nextInputIndex = nextUnusedInputIndex(used);
        used.add(nextInputIndex);
        usedMergeInputs.set(connection.targetClientId, used);
        return [
          cloneConnectionWithTargetInputIndex(connection, nextInputIndex),
        ];
      }

      return [
        cloneConnectionWithTargetInputIndex(connection, targetInputIndex),
      ];
    }

    if (hasExplicitTargetInput(connection)) {
      return targetInputIndex < 2
        ? [cloneConnectionWithTargetInputIndex(connection, targetInputIndex)]
        : [];
    }

    const used = usedMergeInputs.get(connection.targetClientId) || new Set();
    const nextInputIndex = [0, 1].find((input) => !used.has(input));
    if (nextInputIndex == null) {
      return [];
    }

    used.add(nextInputIndex);
    usedMergeInputs.set(connection.targetClientId, used);

    return [cloneConnectionWithTargetInputIndex(connection, nextInputIndex)];
  });
}

export function normalizeMergeConfiguration(configuration = {}) {
  const mode = configuration.mode || "append";

  if (mode === "append") {
    return {
      mode,
      number_inputs: Math.max(
        parseInt(configuration.number_inputs, 10) || 2,
        2
      ),
    };
  }

  if (mode === "choose_branch") {
    return {
      mode,
      use_data_of_input: configuration.use_data_of_input || "input_1",
      use_data_of_input_index:
        configuration.use_data_of_input_index ??
        portIndexFromKey(configuration.use_data_of_input),
      choose_output: configuration.choose_output || "specified_input",
    };
  }

  const combineBy = configuration.combine_by || "matching_fields";
  const normalized = {
    mode,
    combine_by: combineBy,
    resolve_clash: configuration.resolve_clash || "prefer_last",
    merge_mode: configuration.merge_mode || "deep_merge",
    override_empty: Boolean(configuration.override_empty),
    fuzzy_compare: Boolean(configuration.fuzzy_compare),
  };

  if (combineBy === "matching_fields") {
    return {
      ...normalized,
      fields_to_match: configuration.fields_to_match || [],
      join_mode: configuration.join_mode || "keep_matches",
      output_data_from: configuration.output_data_from || "both",
      multiple_matches: configuration.multiple_matches || "all",
    };
  }

  if (combineBy === "position") {
    return {
      ...normalized,
      include_unpaired: Boolean(configuration.include_unpaired),
    };
  }

  return normalized;
}

export function normalizeNodeConfiguration(node) {
  if (node?.type !== "flow:merge") {
    return node;
  }

  return {
    ...node,
    configuration: normalizeMergeConfiguration(node.configuration),
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
