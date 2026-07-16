import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";
import { LOOP_NODE_TYPE } from "./graph-constants";

const DEFAULT_COLOR = "var(--primary-medium)";
const DEFAULT_I18N_PREFIX = "discourse_workflows";
const RUN_SCOPE_LABEL_KEYS = {
  per_item: "discourse_workflows.run_scope.per_item",
  all_items: "discourse_workflows.run_scope.all_items",
};

export function missingTranslation(value) {
  return typeof value === "string" && value.startsWith("[");
}

export function translatedOrNull(key) {
  const value = i18n(key);
  return missingTranslation(value) ? null : value;
}

function humanizeKey(key) {
  return key
    .toString()
    .replace(/_/g, " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function nodeTypeIdentifier(nodeTypeOrIdentifier) {
  if (typeof nodeTypeOrIdentifier === "string") {
    return nodeTypeOrIdentifier;
  }

  return (
    nodeTypeOrIdentifier?.name ||
    nodeTypeOrIdentifier?.identifier ||
    nodeTypeOrIdentifier?.type ||
    ""
  );
}

function resolveNodeType(nodeTypeOrIdentifier) {
  if (!nodeTypeOrIdentifier) {
    return null;
  }

  if (typeof nodeTypeOrIdentifier !== "string") {
    return nodeTypeOrIdentifier;
  }

  return { name: nodeTypeOrIdentifier, identifier: nodeTypeOrIdentifier };
}

export const DEFAULT_TYPE_VERSION = "1.0";

export function typeVersionForNode(node) {
  return node ? (node.typeVersion ?? DEFAULT_TYPE_VERSION) : null;
}

export function resolveNodeTypeVersion(
  nodeTypeOrIdentifier,
  typeVersion = null
) {
  const nodeType = resolveNodeType(nodeTypeOrIdentifier);

  if (!nodeType || typeof nodeTypeOrIdentifier === "string") {
    return nodeType;
  }

  if (!typeVersion || !nodeType.versions) {
    return nodeType.latest || nodeType;
  }

  return nodeType.versions[typeVersion] || null;
}

export function nodeTypeVersion(nodeTypeOrIdentifier, typeVersion = null) {
  return resolveNodeTypeVersion(nodeTypeOrIdentifier, typeVersion)?.version;
}

export function nodeTypeUi(nodeTypeOrIdentifier, typeVersion = null) {
  const nodeType = resolveNodeTypeVersion(nodeTypeOrIdentifier, typeVersion);

  return {
    ...(nodeType?.defaults || {}),
    ...(nodeType?.description?.defaults || {}),
    ...(nodeType?.ui || {}),
  };
}

export function nodeTypeIcon(nodeTypeOrIdentifier, typeVersion = null) {
  return nodeTypeUi(nodeTypeOrIdentifier, typeVersion).icon || null;
}

export function nodeTypeColor(nodeTypeOrIdentifier, typeVersion = null) {
  const color = nodeTypeUi(nodeTypeOrIdentifier, typeVersion).color;
  return color ? `var(--workflow-node-color-${color})` : DEFAULT_COLOR;
}

export function nodeTypeStyle(nodeTypeOrIdentifier, typeVersion = null) {
  return trustHTML(
    `--node-icon-color: ${nodeTypeColor(nodeTypeOrIdentifier, typeVersion)}`
  );
}

export function nodeTypePaletteGroup(nodeTypeOrIdentifier, typeVersion = null) {
  return nodeTypeUi(nodeTypeOrIdentifier, typeVersion).palette_group || null;
}

export function nodeTypeI18nPrefix(nodeTypeOrIdentifier, typeVersion = null) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier, typeVersion).i18n_prefix ||
    resolveNodeTypeVersion(nodeTypeOrIdentifier, typeVersion)?.metadata
      ?.i18n_prefix ||
    DEFAULT_I18N_PREFIX
  );
}

export function nodeTypeI18nScope(nodeTypeOrIdentifier, typeVersion = null) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier, typeVersion).i18n_scope ||
    nodeTypeIdentifier(nodeTypeOrIdentifier)?.split(":").pop() ||
    ""
  );
}

export function nodeTypeLabelKey(nodeTypeOrIdentifier, typeVersion = null) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier, typeVersion).label_key ||
    `discourse_workflows.nodes.${nodeTypeIdentifier(nodeTypeOrIdentifier)}`
  );
}

export function nodeTypeLabel(nodeTypeOrIdentifier, typeVersion = null) {
  return i18n(nodeTypeLabelKey(nodeTypeOrIdentifier, typeVersion));
}

export function nodeTypeDescriptionKey(
  nodeTypeOrIdentifier,
  typeVersion = null
) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier, typeVersion).description_key ||
    `discourse_workflows.node_descriptions.${nodeTypeIdentifier(nodeTypeOrIdentifier)}`
  );
}

export function nodeTypeDescription(nodeTypeOrIdentifier, typeVersion = null) {
  return translatedOrNull(
    nodeTypeDescriptionKey(nodeTypeOrIdentifier, typeVersion)
  );
}

export function nodeTypeCapabilities(nodeTypeOrIdentifier, typeVersion = null) {
  const nodeType = resolveNodeTypeVersion(nodeTypeOrIdentifier, typeVersion);

  return {
    ...(nodeType?.description?.capabilities || {}),
    ...(nodeType?.capabilities || {}),
  };
}

export function nodeTypeIsManuallyTriggerable(
  nodeTypeOrIdentifier,
  typeVersion = null
) {
  return Boolean(
    nodeTypeCapabilities(nodeTypeOrIdentifier, typeVersion)
      .manually_triggerable ||
    resolveNodeTypeVersion(nodeTypeOrIdentifier, typeVersion)
      ?.manually_triggerable
  );
}

export function nodeTypeProducesData(nodeTypeOrIdentifier, typeVersion = null) {
  return (
    nodeTypeCapabilities(nodeTypeOrIdentifier, typeVersion).produces_data !==
    false
  );
}

export function nodeTypePorts(nodeTypeOrIdentifier, typeVersion = null) {
  const nodeType = resolveNodeTypeVersion(nodeTypeOrIdentifier, typeVersion);
  const ports = nodeType?.outputs || nodeType?.ports;

  if (Array.isArray(ports) && ports.length > 0) {
    return ports;
  }

  return [{ key: "main", primary: true }];
}

function indexedPort(port, index) {
  return {
    ...port,
    index: port.index ?? index,
    key: port.key ?? `${index}`,
  };
}

export function nodeTypeInputs(nodeTypeOrIdentifier, node = null) {
  const nodeType = resolveNodeTypeVersion(
    nodeTypeOrIdentifier,
    typeVersionForNode(node)
  );

  const inputs = nodeType?.inputs;

  if (Array.isArray(inputs)) {
    return inputs.map(indexedPort);
  }

  return [{ key: "main", index: 0, required: true }];
}

export function nodeTypeInput(nodeTypeOrIdentifier, keyOrIndex, node = null) {
  return nodeTypeInputs(nodeTypeOrIdentifier, node).find(
    (input) => input.key === keyOrIndex || input.index === keyOrIndex
  );
}

export function nodeTypeInputAcceptsMultipleConnections(
  nodeTypeOrIdentifier,
  keyOrIndex,
  node = null
) {
  return Boolean(
    nodeTypeInput(nodeTypeOrIdentifier, keyOrIndex, node)?.multiple
  );
}

export function nodeTypeInputUsesConnectionIndexes(
  nodeTypeOrIdentifier,
  keyOrIndex,
  node = null
) {
  if (nodeTypeIdentifier(nodeTypeOrIdentifier) === LOOP_NODE_TYPE) {
    return false;
  }

  const input = nodeTypeInput(nodeTypeOrIdentifier, keyOrIndex, node);
  return Boolean(input?.multiple);
}

export function nodeTypeConnectionIndexedInputKey(
  nodeTypeOrIdentifier,
  node = null
) {
  if (nodeTypeIdentifier(nodeTypeOrIdentifier) === LOOP_NODE_TYPE) {
    return null;
  }

  return nodeTypeInputs(nodeTypeOrIdentifier, node).find(
    (input) => input.multiple
  )?.key;
}

export function nodeTypeHasConfigurationFields(
  nodeTypeOrIdentifier,
  node = null
) {
  if (!nodeTypeOrIdentifier || typeof nodeTypeOrIdentifier === "string") {
    return true;
  }

  const nodeType = resolveNodeTypeVersion(
    nodeTypeOrIdentifier,
    typeVersionForNode(node)
  );

  return (
    Object.keys(nodeType?.properties || {}).length > 0 ||
    (nodeType?.credentials || []).length > 0
  );
}

export function nodeTypeInputLabel(
  nodeTypeOrIdentifier,
  keyOrIndex,
  node = null
) {
  const input = nodeTypeInput(nodeTypeOrIdentifier, keyOrIndex, node);

  if (input?.label_key) {
    return (
      translatedOrNull(input.label_key) ||
      input.label ||
      input.display_name ||
      humanizeKey(keyOrIndex)
    );
  }

  return input?.label || input?.display_name || humanizeKey(keyOrIndex);
}

export function nodeTypePort(nodeTypeOrIdentifier, key, typeVersion = null) {
  return (
    nodeTypePorts(nodeTypeOrIdentifier, typeVersion).find(
      (port) => port.key === key
    ) || { key }
  );
}

export function nodeTypePortLabel(nodeTypeOrIdentifier, key, node = null) {
  const port = nodeTypePort(
    nodeTypeOrIdentifier,
    key,
    typeVersionForNode(node)
  );

  if (port.label_key) {
    return translatedOrNull(port.label_key) || port.label || key;
  }

  return port.label || key;
}

export function nodeTypeOutputKeys(nodeTypeOrIdentifier, node = null) {
  return nodeTypePorts(nodeTypeOrIdentifier, typeVersionForNode(node)).map(
    (port) => port.key
  );
}

export function nodeTypePrimaryPort(nodeTypeOrIdentifier) {
  const ports = nodeTypePorts(nodeTypeOrIdentifier);
  return ports.find((port) => port.primary) || ports[0] || { key: "main" };
}

export function nodeTypePrimaryOutputKey(nodeTypeOrIdentifier) {
  return nodeTypePrimaryPort(nodeTypeOrIdentifier).key || "main";
}

function runScopeFromCapability(runScope, node, nodeType) {
  if (typeof runScope === "string") {
    return runScope;
  }

  if (!runScope?.parameter) {
    return null;
  }

  const parameterValue =
    node?.configuration?.[runScope.parameter] ??
    nodeType?.properties?.[runScope.parameter]?.default;

  return runScope.values?.[parameterValue] || null;
}

export function nodeTypeRunScopeLabelKey(nodeTypeOrIdentifier, node = null) {
  const nodeType = resolveNodeTypeVersion(
    nodeTypeOrIdentifier,
    typeVersionForNode(node)
  );
  const runScope = runScopeFromCapability(
    nodeTypeCapabilities(nodeType).run_scope,
    node,
    nodeType
  );

  return RUN_SCOPE_LABEL_KEYS[runScope] || null;
}

export function nodeTypeOperations(nodeTypeOrIdentifier) {
  const nodeType = resolveNodeTypeVersion(nodeTypeOrIdentifier);

  if (Array.isArray(nodeType?.operations) && nodeType.operations.length > 0) {
    return nodeType.operations;
  }

  const operationField = nodeType?.properties?.operation;
  if (
    operationField?.type === "options" &&
    Array.isArray(operationField.options) &&
    operationField.options.length > 1
  ) {
    return operationField.options.map((value) => ({ value }));
  }

  return [];
}

export function nodeTypeOperationLabel(nodeTypeOrIdentifier, operation) {
  const entry = nodeTypeOperations(nodeTypeOrIdentifier).find(
    (item) => item.value === operation
  );

  if (entry?.label_key) {
    return translatedOrNull(entry.label_key) || entry.label || entry.value;
  }

  return entry?.label || entry?.name || entry?.value || operation;
}

export function nodeTypePresenter(nodeTypeOrIdentifier) {
  const operations = nodeTypeOperations(nodeTypeOrIdentifier);

  return {
    icon: nodeTypeIcon(nodeTypeOrIdentifier),
    style: nodeTypeStyle(nodeTypeOrIdentifier),
    label: nodeTypeLabel(nodeTypeOrIdentifier),
    description: nodeTypeDescription(nodeTypeOrIdentifier),
    paletteGroup: nodeTypePaletteGroup(nodeTypeOrIdentifier),
    hasOperations: operations.length > 0,
    operations,
    operationLabel: (operation) =>
      nodeTypeOperationLabel(nodeTypeOrIdentifier, operation),
  };
}
