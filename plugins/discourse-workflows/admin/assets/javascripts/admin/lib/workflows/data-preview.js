import {
  inputPreviewPort,
  latestRunWithOutput,
  outputForRun,
} from "./run-data";
import { fieldsForSchema, schemaFieldsForItems } from "./schema-fields";
import { outputSchemaForNode } from "./schema-graph";

function declaredFieldsForNodeOutput(
  node,
  graph,
  {
    outputIndex = 0,
    prefix = "$json",
    configuration,
    declaredOutputSchemas,
  } = {}
) {
  return fieldsForSchema(
    outputSchemaForNode(node, graph, {
      configuration,
      outputIndex,
      outputSchemas: declaredOutputSchemas,
    }),
    { prefix }
  );
}

function portWasFullyCompacted(port) {
  return (
    port?.truncated === true &&
    (port.item_count ?? 0) > 0 &&
    (port.items?.length ?? 0) === 0
  );
}

export function schemaFieldsForNodeOutput(
  runData,
  nodeName,
  {
    outputIndex = 0,
    prefix = "$json",
    node,
    graph,
    configuration,
    declaredOutputSchemas,
  } = {}
) {
  const run = latestRunWithOutput(runData, nodeName, { node });
  if (!run) {
    return declaredFieldsForNodeOutput(node, graph, {
      outputIndex,
      prefix,
      configuration,
      declaredOutputSchemas,
    });
  }

  const output = outputForRun(run, outputIndex);
  if (portWasFullyCompacted(output)) {
    return declaredFieldsForNodeOutput(node, graph, {
      outputIndex,
      prefix,
      configuration,
      declaredOutputSchemas,
    });
  }

  return schemaFieldsForItems(output?.items || [], { prefix });
}

export function schemaFieldsForNodeInput(
  runData,
  nodeName,
  {
    inputIndex = 0,
    prefix = "$json",
    node,
    sourceNode,
    outputIndex = 0,
    graph,
    pinnedItems,
    declaredOutputSchemas,
  } = {}
) {
  const { port } = inputPreviewPort(runData, nodeName, {
    inputIndex,
    node,
    sourceNode,
    outputIndex,
    pinnedItems,
  });
  if (!port) {
    if (latestRunWithOutput(runData, nodeName, { node })) {
      return [];
    }

    return declaredFieldsForNodeOutput(sourceNode, graph, {
      outputIndex,
      prefix,
      declaredOutputSchemas,
    });
  }

  if (portWasFullyCompacted(port)) {
    return declaredFieldsForNodeOutput(sourceNode, graph, {
      outputIndex,
      prefix,
      declaredOutputSchemas,
    });
  }

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
  { node, sourceNode, outputIndex = 0, pinnedItems } = {}
) {
  const { port, source } = inputPreviewPort(runData, nodeName, {
    inputIndex,
    node,
    sourceNode,
    outputIndex,
    pinnedItems,
  });
  const summary = portSummary(port, "inputIndex");
  if (summary && ["source_output", "pinned"].includes(source)) {
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

export function outputPreviewForNode(
  runData,
  nodeName,
  { pinnedItems, node, graph, configuration, declaredOutputSchemas } = {}
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
    return {
      summary: null,
      fields: declaredFieldsForNodeOutput(node, graph, {
        configuration,
        declaredOutputSchemas,
      }),
    };
  }

  const outputs = run.outputs || [];
  const items = outputPreviewItems(outputs);
  const fields =
    items.length === 0 && outputs.some(portWasFullyCompacted)
      ? declaredFieldsForNodeOutput(node, graph, {
          configuration,
          declaredOutputSchemas,
        })
      : schemaFieldsForItems(items, { prefix: "$json" });

  return {
    summary: combinedPortSummary(
      outputs,
      outputPreviewItemCount(outputs, items)
    ),
    fields,
  };
}
