import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import { STICKY_NOTE_NAME } from "../../../models/sticky-note";
import WorkflowNode from "../../../models/workflow-node";

const NODE_DEFAULTS = {
  "trigger:webhook": () => ({
    path: crypto.randomUUID(),
    http_method: "GET",
  }),
  "trigger:schedule": () => ({
    rule: {
      interval: [{ field: "hours", hoursInterval: 1, triggerAtMinute: 0 }],
    },
  }),
};

export function uniqueNodeName(baseName, takenNames) {
  let name = baseName;
  let counter = 1;
  while (takenNames.has(name)) {
    name = `${baseName} ${counter}`;
    counter++;
  }
  return name;
}

export function defaultNodeName(identifier) {
  return i18n(`discourse_workflows.nodes.${identifier}`);
}

// sticky notes serialize under a fixed name and the server rejects executable
// nodes colliding with it, so it stays reserved even while a workflow has none
export function takenNodeNames(existingNodes) {
  return new Set([STICKY_NOTE_NAME, ...existingNodes.map((n) => n.name)]);
}

export function createNode(
  identifier,
  existingNodes,
  position = null,
  { typeVersion = null, configOverrides = null } = {}
) {
  const allDefaults = applyValueTransformer(
    "workflow-node-defaults",
    NODE_DEFAULTS
  );
  const defaultsFn = allDefaults[identifier];

  return WorkflowNode.create({
    type: identifier,
    typeVersion: typeVersion || "1.0",
    name: uniqueNodeName(
      defaultNodeName(identifier),
      takenNodeNames(existingNodes)
    ),
    configuration: {
      ...(defaultsFn ? defaultsFn() : {}),
      ...(configOverrides || {}),
    },
    position,
  });
}
