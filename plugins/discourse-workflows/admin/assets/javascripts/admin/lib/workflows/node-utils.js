import {
  nodeTypeLabel,
  nodeTypeOutputKeys,
  nodeTypePortLabel,
} from "./node-types";

const NODE_WIDTH = 130;
const NODE_HEIGHT_BASE = 90;
const NODE_HEIGHT_LONG_LABEL = 105;
const NODE_HEIGHT_WITH_DESC = 110;
const PORT_PILL_CHAR_WIDTH = 6;
const PORT_PILL_HORIZONTAL_PADDING = 12;
const PORT_PILL_OFFSET = 18;

export {
  NODE_HEIGHT_BASE,
  NODE_HEIGHT_LONG_LABEL,
  NODE_HEIGHT_WITH_DESC,
  NODE_WIDTH,
};

export function nodeLabel(node) {
  if (
    node.type === "action:ai_agent" &&
    typeof node.configuration?.agent_name === "string" &&
    node.configuration.agent_name.trim()
  ) {
    return node.configuration.agent_name.trim();
  }
  return node.name || nodeTypeLabel(node.type);
}

export function nodeDescription(node) {
  return node.configuration?.description || "";
}

function normalizedPortLabel(label) {
  return (label || "").replaceAll("_", " ");
}

function estimatePortLabelWidth(label) {
  return (
    normalizedPortLabel(label).length * PORT_PILL_CHAR_WIDTH +
    PORT_PILL_HORIZONTAL_PADDING
  );
}

function resolveOutputKeys(nodeTypeOrIdentifier, outputKeys) {
  if (Array.isArray(outputKeys) && outputKeys.length > 0) {
    return outputKeys;
  }

  return nodeTypeOutputKeys(nodeTypeOrIdentifier);
}

export function nodeWidth(node, { nodeType = null, outputKeys } = {}) {
  const nodeTypeOrIdentifier = nodeType || node?.type;
  const keys = resolveOutputKeys(nodeTypeOrIdentifier, outputKeys);

  if (keys.length < 2) {
    return NODE_WIDTH;
  }

  const maxPortLabelWidth = Math.max(
    0,
    ...keys.map((key) =>
      estimatePortLabelWidth(
        nodeTypePortLabel(nodeTypeOrIdentifier, key) || key
      )
    )
  );

  return NODE_WIDTH + PORT_PILL_OFFSET + maxPortLabelWidth;
}

const LABEL_WRAP_THRESHOLD = 15;

export function nodeHeight(node) {
  if (nodeDescription(node)) {
    return NODE_HEIGHT_WITH_DESC;
  }
  const label = nodeLabel(node);
  return label && label.length > LABEL_WRAP_THRESHOLD
    ? NODE_HEIGHT_LONG_LABEL
    : NODE_HEIGHT_BASE;
}
