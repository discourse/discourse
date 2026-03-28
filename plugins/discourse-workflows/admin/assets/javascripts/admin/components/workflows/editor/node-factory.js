import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";
import WorkflowNode from "../../../models/workflow-node";

const NODE_DEFAULTS = {
  "trigger:webhook": () => ({
    path: crypto.randomUUID(),
    http_method: "GET",
  }),
  "trigger:schedule": () => ({
    cron: "0 * * * *",
  }),
};

export function generateNodeName(identifier, existingNodes) {
  const baseName = i18n(`discourse_workflows.nodes.${identifier}`);

  const existingNames = new Set(existingNodes.map((n) => n.name));
  let name = baseName;
  let counter = 1;
  while (existingNames.has(name)) {
    name = `${baseName} ${counter}`;
    counter++;
  }
  return name;
}

export function createNode(
  identifier,
  existingNodes,
  position = null,
  { typeVersion = null } = {}
) {
  const allDefaults = applyValueTransformer(
    "workflow-node-defaults",
    NODE_DEFAULTS
  );
  const defaultsFn = allDefaults[identifier];

  return WorkflowNode.create({
    type: identifier,
    type_version: typeVersion || "1.0",
    name: generateNodeName(identifier, existingNodes),
    configuration: defaultsFn ? defaultsFn() : {},
    position,
  });
}
