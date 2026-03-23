import { applyValueTransformer } from "discourse/lib/transformer";

const NODE_DEFAULTS = {
  "trigger:webhook": () => ({
    path: crypto.randomUUID(),
    http_method: "GET",
  }),
};

function generateNodeName(identifier, existingNodes) {
  const baseName = identifier
    .split(":")
    .pop()
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());

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

  const node = {
    clientId: crypto.randomUUID(),
    type: identifier,
    type_version: typeVersion || "1.0",
    name: generateNodeName(identifier, existingNodes),
    configuration: defaultsFn ? defaultsFn() : {},
  };

  if (position) {
    node.position = position;
  }

  return node;
}
