import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

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

const DEFAULT_NODE_ICONS = {
  "trigger:manual": { icon: "arrow-pointer" },
  "trigger:webhook": { icon: "globe", colorKey: "purple" },
  "trigger:stale_topic": { icon: "clock", colorKey: "deep-orange" },
  "trigger:schedule": { icon: "calendar-days", colorKey: "orange" },
  "trigger:topic_closed": { icon: "lock", colorKey: "grey" },
  "trigger:post_created": { icon: "comment", colorKey: "indigo" },
  "trigger:topic_created": { icon: "plus", colorKey: "teal" },
  "trigger:topic_category_changed": {
    icon: "folder-open",
    colorKey: "deep-orange",
  },
  "trigger:form": { icon: "rectangle-list", colorKey: "teal" },
  "condition:if": { icon: "arrows-split-up-and-left", colorKey: "blue" },
  "condition:filter": { icon: "filter", colorKey: "violet" },
  "action:code": { icon: "code", colorKey: "red" },
  "action:ai_agent": { icon: "robot", colorKey: "pink" },
  "action:append_tags": { icon: "tags", colorKey: "orange" },
  "action:set_fields": { icon: "list", colorKey: "green" },
  "action:fetch_topic": { icon: "download", colorKey: "light-blue" },
  "action:create_post": { icon: "reply", colorKey: "teal" },
  "action:create_topic": { icon: "plus", colorKey: "light-green" },
  "action:split_out": { icon: "arrows-turn-to-dots", colorKey: "yellow" },
  "action:http_request": { icon: "globe", colorKey: "indigo" },
  "action:data_table": { icon: "table", prefix: "fas", colorKey: "violet" },
  "action:wait_for_approval": { icon: "user-check", colorKey: "cyan" },
  "action:form": { icon: "rectangle-list", colorKey: "blue" },
  "action:award_badge": { icon: "certificate", colorKey: "yellow" },
  "action:respond_to_webhook": { icon: "reply", colorKey: "purple" },
  "core:loop_over_items": { icon: "arrow-rotate-right", colorKey: "brown" },
};

export function getNodeIcons() {
  return applyValueTransformer("workflow-node-icons", DEFAULT_NODE_ICONS);
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
