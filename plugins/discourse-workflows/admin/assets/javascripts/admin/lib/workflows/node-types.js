import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { getNodeColor, getNodeIcons } from "./node-utils";

let cachedNodeTypes = null;

export async function loadNodeTypes() {
  if (cachedNodeTypes) {
    return cachedNodeTypes;
  }

  try {
    const result = await ajax(
      "/admin/plugins/discourse-workflows/node-types.json"
    );
    cachedNodeTypes = result.node_types;
    return cachedNodeTypes;
  } catch (e) {
    popupAjaxError(e);
    return [];
  }
}

export function nodeTypeIcon(nodeType) {
  return getNodeIcons()[nodeType.identifier]?.icon || null;
}

export function nodeTypeLabel(nodeType) {
  return i18n(`discourse_workflows.nodes.${nodeType.identifier}`);
}

export function nodeTypeDescription(nodeType) {
  const key = `discourse_workflows.node_descriptions.${nodeType.identifier}`;
  const result = i18n(key);
  return result.startsWith("[") ? null : result;
}

export function nodeTypeStyle(nodeType) {
  const color = getNodeColor(nodeType.identifier);
  return color ? trustHTML(`--node-icon-color: ${color}`) : "";
}
