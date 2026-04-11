import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

const DEFAULT_COLOR = "var(--primary-medium)";
const DEFAULT_PROPERTY_I18N_PREFIX = "discourse_workflows";

export function missingTranslation(value) {
  return typeof value === "string" && value.startsWith("[");
}

export function translatedOrNull(key) {
  const value = i18n(key);
  return missingTranslation(value) ? null : value;
}

function nodeTypeIdentifier(nodeTypeOrIdentifier) {
  if (typeof nodeTypeOrIdentifier === "string") {
    return nodeTypeOrIdentifier;
  }

  return nodeTypeOrIdentifier?.identifier || nodeTypeOrIdentifier?.type || "";
}

function resolveNodeType(nodeTypeOrIdentifier) {
  if (!nodeTypeOrIdentifier) {
    return null;
  }

  if (typeof nodeTypeOrIdentifier !== "string") {
    return nodeTypeOrIdentifier;
  }

  return { identifier: nodeTypeOrIdentifier };
}

export function nodeTypeUi(nodeTypeOrIdentifier) {
  return resolveNodeType(nodeTypeOrIdentifier)?.ui || {};
}

export function nodeTypeIcon(nodeTypeOrIdentifier) {
  return nodeTypeUi(nodeTypeOrIdentifier).icon || null;
}

export function nodeTypeColor(nodeTypeOrIdentifier) {
  const color = nodeTypeUi(nodeTypeOrIdentifier).color;
  return color ? `var(--workflow-node-color-${color})` : DEFAULT_COLOR;
}

export function nodeTypeStyle(nodeTypeOrIdentifier) {
  return trustHTML(`--node-icon-color: ${nodeTypeColor(nodeTypeOrIdentifier)}`);
}

export function nodeTypePaletteGroup(nodeTypeOrIdentifier) {
  return nodeTypeUi(nodeTypeOrIdentifier).palette_group || null;
}

export function nodeTypePropertyI18nPrefix(nodeTypeOrIdentifier) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier).property_i18n_prefix ||
    resolveNodeType(nodeTypeOrIdentifier)?.metadata?.i18n_prefix ||
    DEFAULT_PROPERTY_I18N_PREFIX
  );
}

export function nodeTypePropertyI18nScope(nodeTypeOrIdentifier) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier).property_i18n_scope ||
    nodeTypeIdentifier(nodeTypeOrIdentifier)?.split(":").pop() ||
    ""
  );
}

export function nodeTypeLabelKey(nodeTypeOrIdentifier) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier).label_key ||
    `discourse_workflows.nodes.${nodeTypeIdentifier(nodeTypeOrIdentifier)}`
  );
}

export function nodeTypeLabel(nodeTypeOrIdentifier) {
  return i18n(nodeTypeLabelKey(nodeTypeOrIdentifier));
}

export function nodeTypeDescriptionKey(nodeTypeOrIdentifier) {
  return (
    nodeTypeUi(nodeTypeOrIdentifier).description_key ||
    `discourse_workflows.node_descriptions.${nodeTypeIdentifier(nodeTypeOrIdentifier)}`
  );
}

export function nodeTypeDescription(nodeTypeOrIdentifier) {
  return translatedOrNull(nodeTypeDescriptionKey(nodeTypeOrIdentifier));
}

export function nodeTypeCapabilities(nodeTypeOrIdentifier) {
  return resolveNodeType(nodeTypeOrIdentifier)?.capabilities || {};
}

export function nodeTypeIsManuallyTriggerable(nodeTypeOrIdentifier) {
  return Boolean(
    nodeTypeCapabilities(nodeTypeOrIdentifier).manually_triggerable ||
    resolveNodeType(nodeTypeOrIdentifier)?.manually_triggerable
  );
}

export function nodeTypePorts(nodeTypeOrIdentifier) {
  const ports = resolveNodeType(nodeTypeOrIdentifier)?.ports;

  if (Array.isArray(ports) && ports.length > 0) {
    return ports;
  }

  return [{ key: "main", primary: true }];
}

export function nodeTypePort(nodeTypeOrIdentifier, key) {
  return (
    nodeTypePorts(nodeTypeOrIdentifier).find((port) => port.key === key) || {
      key,
    }
  );
}

export function nodeTypePortLabel(nodeTypeOrIdentifier, key) {
  const port = nodeTypePort(nodeTypeOrIdentifier, key);

  if (port.label_key) {
    return translatedOrNull(port.label_key) || port.label || key;
  }

  return port.label || key;
}

export function nodeTypeOutputKeys(nodeTypeOrIdentifier) {
  return nodeTypePorts(nodeTypeOrIdentifier).map((port) => port.key);
}

export function nodeTypePrimaryPort(nodeTypeOrIdentifier) {
  const ports = nodeTypePorts(nodeTypeOrIdentifier);
  return ports.find((port) => port.primary) || ports[0] || { key: "main" };
}

export function nodeTypePrimaryOutputKey(nodeTypeOrIdentifier) {
  return nodeTypePrimaryPort(nodeTypeOrIdentifier).key || "main";
}

export function nodeTypeOperations(nodeTypeOrIdentifier) {
  const nodeType = resolveNodeType(nodeTypeOrIdentifier);

  if (Array.isArray(nodeType?.operations) && nodeType.operations.length > 0) {
    return nodeType.operations;
  }

  const operationField = nodeType?.configuration_schema?.operation;
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
