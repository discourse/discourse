import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

const NODE_HEIGHT_BASE = 44;
const NODE_HEIGHT_WITH_DESC = 62;
const CHAR_WIDTH = 7.8;
const PADDING_LEFT_ICON = 36;
const PADDING_LEFT_TEXT = 14;
const PADDING_RIGHT = 14;
const MIN_WIDTH = 80;

export { NODE_HEIGHT_BASE, NODE_HEIGHT_WITH_DESC };

const DEFAULT_NODE_ICONS = {
  "trigger:manual": { icon: "play", color: "#4caf50" },
  "trigger:webhook": { icon: "globe", color: "#7c4dff" },
  "trigger:stale_topic": { icon: "clock", color: "#ff7043" },
  "trigger:schedule": { icon: "calendar-days", color: "#ff9800" },
  "trigger:topic_closed": { icon: "lock", color: "#78909c" },
  "trigger:post_created": { icon: "comment", color: "#5c6bc0" },
  "trigger:topic_created": { icon: "plus", color: "#26a69a" },
  "trigger:topic_category_changed": { icon: "folder-open", color: "#ff8a65" },
  "trigger:form": { icon: "rectangle-list", color: "#26a69a" },
  "condition:if": { icon: "arrows-split-up-and-left", color: "#42a5f5" },
  "condition:filter": { icon: "filter", color: "#ab47bc" },
  "action:code": { icon: "code", color: "#ef5350" },
  "action:ai_agent": { icon: "robot", color: "#ec407a" },
  "action:append_tags": { icon: "tags", color: "#ffa726" },
  "action:set_fields": { icon: "list", color: "#66bb6a" },
  "action:fetch_topic": { icon: "download", color: "#29b6f6" },
  "action:create_post": { icon: "reply", color: "#26a69a" },
  "action:create_topic": { icon: "plus", color: "#8bc34a" },
  "action:split_out": { icon: "arrows-turn-to-dots", color: "#ffca28" },
  "action:http_request": { icon: "globe", color: "#5c6bc0" },
  "action:data_table": { icon: "table", prefix: "fas", color: "#8B5CF6" },
  "action:wait_for_approval": { icon: "user-check", color: "#26c6da" },
  "action:form": { icon: "rectangle-list", color: "#42a5f5" },
  "action:award_badge": { icon: "certificate", color: "#f9a825" },
  "core:loop_over_items": { icon: "arrow-rotate-right", color: "#8d6e63" },
};

export function getNodeIcons() {
  return applyValueTransformer("workflow-node-icons", DEFAULT_NODE_ICONS);
}

export function getNodeColor(identifier) {
  const icons = getNodeIcons();
  return icons[identifier]?.color || "var(--primary-medium)";
}

export function nodeLabel(node) {
  if (node.type === "trigger:manual") {
    return "";
  }

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

export function nodeHeight(node) {
  return nodeDescription(node) ? NODE_HEIGHT_WITH_DESC : NODE_HEIGHT_BASE;
}

export function nodeWidth(node) {
  const label = nodeLabel(node);
  const desc = nodeDescription(node);
  const hasIcon = !!getNodeIcons()[node.type]?.icon;
  const textStart = hasIcon ? PADDING_LEFT_ICON : PADDING_LEFT_TEXT;
  const labelWidth = label.length * CHAR_WIDTH;
  const descWidth = desc ? desc.length * 6.5 : 0;
  const contentWidth = Math.max(labelWidth, descWidth);
  return Math.max(
    MIN_WIDTH,
    Math.ceil(textStart + contentWidth + PADDING_RIGHT)
  );
}
