import {
  normalizeSourceOutputIndex,
  normalizeTargetInputIndex,
} from "./graph-constants";

const TYPE_EXEMPLARS = {
  string: "",
  integer: 0,
  number: 0,
  boolean: false,
  array: [],
  object: {},
  null: null,
  unknown: null,
};

function classifyValue(value) {
  if (Array.isArray(value)) {
    return "array";
  }

  if (value === null || value === undefined) {
    return value === null ? "null" : "unknown";
  }

  if (typeof value === "number") {
    return "number";
  }

  if (typeof value === "boolean") {
    return "boolean";
  }

  if (typeof value === "object") {
    return "object";
  }

  return "string";
}

function propertySegment(key) {
  return /^[A-Za-z_$][\w$]*$/.test(key)
    ? `.${key}`
    : `[${JSON.stringify(key)}]`;
}

export function nodeOutputFirstJsonPath(nodeName, { outputIndex = 0 } = {}) {
  const branchArg = outputIndex === 0 ? "" : outputIndex;
  return `$(${JSON.stringify(nodeName)}).first(${branchArg}).json`;
}

export function nodeOutputLinkedItemJsonPath(nodeName) {
  return `$(${JSON.stringify(nodeName)}).item.json`;
}

export function nodeOutputJsonPath(
  runData,
  nodeName,
  { outputIndex = 0, node } = {}
) {
  const run = latestRunWithOutput(runData, nodeName, { node });
  const output = outputForRun(run, outputIndex);
  const itemCount = output?.item_count ?? output?.items?.length ?? 0;

  if (itemCount === 1) {
    return nodeOutputFirstJsonPath(nodeName, { outputIndex });
  }

  return nodeOutputLinkedItemJsonPath(nodeName);
}

export function nodeOutputItemJsonPath(
  nodeName,
  { outputIndex = 0, itemIndex = "$itemIndex" } = {}
) {
  return `$(${JSON.stringify(nodeName)}).all(${outputIndex})[${itemIndex}].json`;
}

export function inputFieldPrefixForConnection(
  connection,
  previousNode,
  { primaryConnection, itemPrefix = "$json" } = {}
) {
  if (!connection || connection === primaryConnection || !previousNode?.name) {
    return itemPrefix;
  }

  return nodeOutputItemJsonPath(previousNode.name, {
    outputIndex: outputIndexForConnection(connection),
  });
}

export function outputIndexForConnection(connection) {
  return normalizeSourceOutputIndex(connection);
}

export function inputIndexForConnection(connection) {
  return normalizeTargetInputIndex(connection);
}

function arraySegment(index) {
  return `[${index}]`;
}

function compactObject(obj) {
  return Object.fromEntries(
    Object.entries(obj).filter(([, value]) => value !== undefined)
  );
}

function representativeValue(values) {
  const presentValue = values.find(
    (value) => value !== undefined && value !== null
  );
  if (presentValue !== undefined) {
    return presentValue;
  }

  return values.includes(null) ? null : undefined;
}

function childValuesForObject(values, childKey) {
  return values.map((value) =>
    value && typeof value === "object" && !Array.isArray(value)
      ? value[childKey]
      : undefined
  );
}

function childValuesForArray(values, index) {
  return values.map((value) =>
    Array.isArray(value) ? value[index] : undefined
  );
}

function schemaFromValues(values, key, path) {
  const value = representativeValue(values);
  const type = classifyValue(value);
  const field = compactObject({
    key,
    id: path,
    type,
    value,
  });

  if (type === "object") {
    const childKeys = new Set();
    for (const candidate of values) {
      if (
        candidate &&
        typeof candidate === "object" &&
        !Array.isArray(candidate)
      ) {
        Object.keys(candidate).forEach((childKey) => childKeys.add(childKey));
      }
    }
    field.children = [...childKeys].map((childKey) =>
      schemaFromValues(
        childValuesForObject(values, childKey),
        childKey,
        `${path}${propertySegment(childKey)}`
      )
    );
  }

  if (type === "array") {
    const childIndexes = new Set();
    for (const candidate of values) {
      if (Array.isArray(candidate)) {
        candidate.forEach((_, index) => childIndexes.add(index));
      }
    }
    field.children = [...childIndexes].map((index) =>
      schemaFromValues(
        childValuesForArray(values, index),
        index.toString(),
        `${path}${arraySegment(index)}`
      )
    );
  }

  return field;
}

export function schemaFieldsForItems(items = [], { prefix = "$json" } = {}) {
  const jsonItems = items
    .map((item) => item?.json)
    .filter((json) => json && typeof json === "object" && !Array.isArray(json));

  const keys = new Set();
  jsonItems.forEach((json) =>
    Object.keys(json).forEach((key) => keys.add(key))
  );

  const jsonFields = [...keys].map((key) =>
    schemaFromValues(
      jsonItems.map((json) => json[key]),
      key,
      `${prefix}${propertySegment(key)}`
    )
  );

  return jsonFields;
}

export function exemplarFromFields(fields = []) {
  const obj = Object.create(null);

  for (const field of fields) {
    if (field.type === "object" && field.children?.length) {
      obj[field.key] = exemplarFromFields(field.children);
    } else if (field.type === "array" && field.children?.length) {
      const child = field.children[0];
      if (child?.type === "object") {
        obj[field.key] = [exemplarFromFields(child.children || [])];
      } else if (child?.value !== undefined) {
        obj[field.key] = [child.value];
      } else {
        obj[field.key] = [TYPE_EXEMPLARS[child?.type] ?? TYPE_EXEMPLARS.string];
      }
    } else if (field.value !== undefined) {
      obj[field.key] = field.value;
    } else {
      obj[field.key] = TYPE_EXEMPLARS[field.type] ?? TYPE_EXEMPLARS.string;
    }
  }

  return obj;
}

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

function inputPreviewPort(
  runData,
  nodeName,
  { inputIndex = 0, node, sourceNode, outputIndex = 0 } = {}
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

export function schemaFieldsForNodeOutput(
  runData,
  nodeName,
  { outputIndex = 0, prefix = "$json", node } = {}
) {
  const run = latestRunWithOutput(runData, nodeName, { node });
  const output = outputForRun(run, outputIndex);
  return schemaFieldsForItems(output?.items || [], { prefix });
}

export function schemaFieldsForNodeInput(
  runData,
  nodeName,
  { inputIndex = 0, prefix = "$json", node, sourceNode, outputIndex = 0 } = {}
) {
  const { port } = inputPreviewPort(runData, nodeName, {
    inputIndex,
    node,
    sourceNode,
    outputIndex,
  });
  return schemaFieldsForItems(port?.items || [], { prefix });
}

function portSummary(port, indexKey) {
  if (!port) {
    return null;
  }

  return {
    [indexKey]: port.index,
    itemCount: port.item_count ?? port.items?.length ?? 0,
    truncated: port.truncated === true,
  };
}

export function outputSummaryForNode(
  runData,
  nodeName,
  outputIndex = 0,
  { node } = {}
) {
  const run = latestRunWithOutput(runData, nodeName, { node });
  return portSummary(outputForRun(run, outputIndex), "outputIndex");
}

export function inputSummaryForNode(
  runData,
  nodeName,
  inputIndex = 0,
  { node, sourceNode, outputIndex = 0 } = {}
) {
  const { port, source } = inputPreviewPort(runData, nodeName, {
    inputIndex,
    node,
    sourceNode,
    outputIndex,
  });
  const summary = portSummary(port, "inputIndex");
  if (summary && source === "source_output") {
    summary.inputIndex = inputIndex;
  }
  return summary;
}

function combinedPortSummary(ports, itemCount) {
  if (!ports) {
    return null;
  }

  return {
    itemCount,
    truncated: ports.some((port) => port.truncated === true),
  };
}

function outputPreviewItems(outputs) {
  if (outputs.length <= 1) {
    return outputs[0]?.items || [];
  }

  return outputs
    .map((output) => output.items?.find((item) => item))
    .filter(Boolean);
}

function outputPreviewItemCount(outputs, items) {
  if (outputs.length <= 1) {
    return outputs[0]?.item_count ?? items.length;
  }

  return items.length ? 1 : 0;
}

export function outputSchemaForNode(
  runData,
  nodeName,
  { pinnedItems, node } = {}
) {
  if (Array.isArray(pinnedItems) && pinnedItems.length > 0) {
    return {
      summary: {
        itemCount: pinnedItems.length,
        truncated: false,
        pinned: true,
      },
      fields: schemaFieldsForItems(pinnedItems, { prefix: "$json" }),
    };
  }

  const run = latestRunWithOutput(runData, nodeName, { node });
  if (!run) {
    return { summary: null, fields: [] };
  }

  const outputs = run.outputs || [];
  const items = outputPreviewItems(outputs);

  return {
    summary: combinedPortSummary(
      outputs,
      outputPreviewItemCount(outputs, items)
    ),
    fields: schemaFieldsForItems(items, { prefix: "$json" }),
  };
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
    .sort((left, right) => {
      return (
        inputIndexForConnection(left) - inputIndexForConnection(right) ||
        left.sourceClientId.localeCompare(right.sourceClientId) ||
        outputIndexForConnection(left) - outputIndexForConnection(right)
      );
    });
}

export function previousConnectionForNode(node, graph, visited = new Set()) {
  const connections = inputConnectionsForNode(node, graph, visited);
  return connections[0] || null;
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
