import {
  normalizeSourceOutputIndex,
  normalizeTargetInputIndex,
} from "./graph-constants";
import { latestRunWithOutput, outputForRun } from "./run-data";

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
  { outputIndex = 0, node, itemCount } = {}
) {
  const run = latestRunWithOutput(runData, nodeName, { node });
  const output = outputForRun(run, outputIndex);
  const effectiveItemCount =
    itemCount ?? output?.item_count ?? output?.items?.length ?? 0;

  if (effectiveItemCount === 1) {
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
