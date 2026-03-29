import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import { getCachedNodeTypes } from "./node-types";

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

function buildNodeIcons() {
  const icons = {};
  const cached = getCachedNodeTypes();
  const nodeTypes = cached?.node_types;
  if (nodeTypes) {
    for (const nt of nodeTypes) {
      if (nt.icon) {
        icons[nt.identifier] = {
          icon: nt.icon,
          ...(nt.color_key && { colorKey: nt.color_key }),
        };
      }
    }
  }
  return icons;
}

export function getNodeIcons() {
  return applyValueTransformer("workflow-node-icons", buildNodeIcons());
}

export function getNodeColor(identifier) {
  const icons = getNodeIcons();
  const key = icons[identifier]?.colorKey;
  return key ? `var(--workflow-node-color-${key})` : "var(--primary-medium)";
}

export function nodeLabel(node) {
  const agentName =
    node.type === "action:ai_agent" &&
    typeof node.configuration?.agent_name === "string"
      ? node.configuration.agent_name.trim()
      : null;

  if (agentName) {
    return agentName;
  }

  return node.name || i18n(`discourse_workflows.nodes.${node.type}`);
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

export function nodeWidth() {
  return NODE_WIDTH;
}
