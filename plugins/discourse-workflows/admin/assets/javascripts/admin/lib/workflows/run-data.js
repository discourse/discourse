function nodeRunMatches(run, node) {
  if (!node) {
    return true;
  }

  const nodeId = node.id ?? node.clientId;
  if (run?.node_id && nodeId && run.node_id.toString() !== nodeId.toString()) {
    return false;
  }

  if (run?.node_type && node.type && run.node_type !== node.type) {
    return false;
  }

  return true;
}

function portSourceMatches(port, sourceNode, outputIndex) {
  if (!sourceNode) {
    return true;
  }

  const source = port?.source;
  if (!source) {
    return false;
  }

  return (
    source.node_name === sourceNode.name &&
    (source.output_index ?? 0).toString() === outputIndex.toString()
  );
}

function latestSuccessfulRun(runData, nodeName, { node } = {}) {
  const runs = (runData?.[nodeName] || []).filter(
    (run) => run.status === "success" && nodeRunMatches(run, node)
  );
  if (!runs?.length) {
    return null;
  }

  return runs[runs.length - 1] || null;
}

export function latestRunWithOutput(runData, nodeName, { node } = {}) {
  return latestSuccessfulRun(runData, nodeName, { node });
}

export function latestRunWithInput(
  runData,
  nodeName,
  { inputIndex = 0, node, sourceNode, outputIndex = 0 } = {}
) {
  const run = latestSuccessfulRun(runData, nodeName, { node });
  if (!inputForRun(run, inputIndex, { sourceNode, outputIndex })) {
    return null;
  }

  return run;
}

function portForRun(run, portKey, portIndex = 0) {
  if (!run) {
    return null;
  }

  return (run[portKey] || []).find((port) => port.index === portIndex) || null;
}

export function outputForRun(run, outputIndex = 0) {
  return portForRun(run, "outputs", outputIndex);
}

export function inputForRun(
  run,
  inputIndex = 0,
  { sourceNode, outputIndex = 0 } = {}
) {
  const input = portForRun(run, "inputs", inputIndex);
  if (!input || !portSourceMatches(input, sourceNode, outputIndex)) {
    return null;
  }

  return input;
}

function connectedSourceOutputForInput(
  runData,
  nodeName,
  { node, sourceNode, outputIndex = 0 } = {}
) {
  if (latestSuccessfulRun(runData, nodeName, { node }) || !sourceNode?.name) {
    return null;
  }

  const sourceRun = latestRunWithOutput(runData, sourceNode.name, {
    node: sourceNode,
  });
  return outputForRun(sourceRun, outputIndex);
}

export function inputPreviewPort(
  runData,
  nodeName,
  { inputIndex = 0, node, sourceNode, outputIndex = 0, pinnedItems } = {}
) {
  const run = latestRunWithInput(runData, nodeName, {
    inputIndex,
    node,
    sourceNode,
    outputIndex,
  });
  const input = inputForRun(run, inputIndex, { sourceNode, outputIndex });
  if (input) {
    return { port: input, source: "input" };
  }

  if (latestSuccessfulRun(runData, nodeName, { node })) {
    return { port: null, source: null };
  }

  if (Array.isArray(pinnedItems)) {
    return {
      port: {
        index: inputIndex,
        items: pinnedItems,
        item_count: pinnedItems.length,
        truncated: false,
      },
      source: "pinned",
    };
  }

  const output = connectedSourceOutputForInput(runData, nodeName, {
    node,
    sourceNode,
    outputIndex,
  });
  if (output) {
    return { port: output, source: "source_output" };
  }

  return { port: null, source: null };
}
