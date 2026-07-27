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

const RUNS_WITH_FLOWING_OUTPUT = ["success", "filtered", "skipped"];

const EXECUTED_RUN_STATUSES = ["success", "filtered"];

function latestRunWithStatus(runData, nodeName, statuses, { node } = {}) {
  const runs = (runData?.[nodeName] || []).filter(
    (run) => statuses.includes(run.status) && nodeRunMatches(run, node)
  );
  if (!runs?.length) {
    return null;
  }

  return runs[runs.length - 1] || null;
}

function latestExecutedRun(runData, nodeName, { node } = {}) {
  return latestRunWithStatus(runData, nodeName, EXECUTED_RUN_STATUSES, {
    node,
  });
}

export function latestRunWithOutput(runData, nodeName, { node } = {}) {
  return latestRunWithStatus(runData, nodeName, RUNS_WITH_FLOWING_OUTPUT, {
    node,
  });
}

export function latestRunWithInput(
  runData,
  nodeName,
  { inputIndex = 0, node, sourceNode, outputIndex = 0 } = {}
) {
  const run = latestExecutedRun(runData, nodeName, { node });
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
  if (latestExecutedRun(runData, nodeName, { node }) || !sourceNode?.name) {
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

  if (latestExecutedRun(runData, nodeName, { node })) {
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
