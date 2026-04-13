import { nodeTypeLabel } from "./node-types";

const NODE_WIDTH = 130;
const NODE_HEIGHT_BASE = 90;
const NODE_HEIGHT_LONG_LABEL = 105;
const NODE_HEIGHT_WITH_DESC = 110;

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
