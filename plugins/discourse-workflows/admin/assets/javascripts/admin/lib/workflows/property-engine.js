import { i18n } from "discourse-i18n";

const CUSTOM_I18N_SCOPES = {
  "action:data_table": "data_table_node",
  "condition:filter": "if_condition",
  "condition:if": "if_condition",
};
const DEFAULT_I18N_PREFIX = "discourse_workflows";

function cloneValue(value) {
  return value === undefined ? undefined : structuredClone(value);
}

function missingTranslation(value) {
  return typeof value === "string" && value.startsWith("[");
}

function hasTranslation(key) {
  return !missingTranslation(i18n(key));
}

function humanize(value) {
  return value
    .toString()
    .replace(/_/g, " ")
    .replace(/\b\w/g, (char) => char.toUpperCase());
}

function fieldUi(schema = {}) {
  return schema.ui || {};
}

function fallbackValueForType(type) {
  switch (type) {
    case "boolean":
      return false;
    case "collection":
    case "array":
      return [];
    default:
      return "";
  }
}

function translationWithFallback(key, fallback = null) {
  const value = i18n(key);
  return missingTranslation(value) ? fallback : value;
}

function translationKeyWithFallback(keys = []) {
  return keys.find((key) => hasTranslation(key)) || null;
}

function nodeIdentifier(nodeDefinitionOrType) {
  if (typeof nodeDefinitionOrType === "string") {
    return nodeDefinitionOrType;
  }

  return nodeDefinitionOrType?.identifier || nodeDefinitionOrType?.type || "";
}

function nodeMetadata(nodeDefinitionOrType) {
  return nodeDefinitionOrType?.metadata || {};
}

export function findNodeType(nodeTypes, nodeType) {
  return (
    nodeTypes?.find((definition) => definition.identifier === nodeType) || null
  );
}

export function getConfigurationSchema(
  nodeTypes,
  nodeType,
  typeVersion = null
) {
  const definition = findNodeType(nodeTypes, nodeType);

  if (!definition) {
    return {};
  }

  const versionedSchemas = definition.configuration_schema_versions;
  if (typeVersion && versionedSchemas?.[typeVersion]) {
    return versionedSchemas[typeVersion];
  }

  return definition.configuration_schema || {};
}

export function normalizeSchema(schema = {}) {
  return Object.entries(schema).map(([name, field]) => ({
    name,
    ...field,
  }));
}

export function propertyI18nPrefix(nodeDefinitionOrType) {
  return nodeMetadata(nodeDefinitionOrType).i18n_prefix || DEFAULT_I18N_PREFIX;
}

export function propertyScope(nodeDefinitionOrType) {
  const identifier = nodeIdentifier(nodeDefinitionOrType);
  return CUSTOM_I18N_SCOPES[identifier] || identifier?.split(":").pop() || "";
}

function i18nBase(nodeDefinitionOrType) {
  return `${propertyI18nPrefix(nodeDefinitionOrType)}.${propertyScope(nodeDefinitionOrType)}`;
}

export function propertyLabel(nodeDefinitionOrType, fieldName) {
  const base = i18nBase(nodeDefinitionOrType);

  return (
    translationWithFallback(`${base}.${fieldName}`) ||
    translationWithFallback(`${base}.${fieldName}.title`) ||
    humanize(fieldName)
  );
}

export function propertyDescription(nodeDefinitionOrType, fieldName) {
  return translationWithFallback(
    `${i18nBase(nodeDefinitionOrType)}.${fieldName}_description`
  );
}

export function propertyPlaceholder(nodeDefinitionOrType, fieldName) {
  return translationWithFallback(
    `${i18nBase(nodeDefinitionOrType)}.${fieldName}_placeholder`
  );
}

export function propertySelectNoneKey(nodeDefinitionOrType, fieldName) {
  const base = i18nBase(nodeDefinitionOrType);
  const selectField = fieldName.replace(/_id$/, "");

  return translationKeyWithFallback([
    `${base}.select_${selectField}`,
    `${base}.${fieldName}_placeholder`,
  ]);
}

export function collectionAddLabel(nodeDefinitionOrType, fieldName) {
  const singular = fieldName.endsWith("s") ? fieldName.slice(0, -1) : fieldName;

  return (
    translationWithFallback(
      `${i18nBase(nodeDefinitionOrType)}.add_${singular}`
    ) || i18n("discourse_workflows.property_engine.add_item")
  );
}

export function normalizeOptions(options = []) {
  return options.map((option) =>
    typeof option === "object" ? option : { value: option }
  );
}

export function propertyOptionLabel(nodeDefinitionOrType, fieldName, option) {
  const base = i18nBase(nodeDefinitionOrType);

  return (
    translationWithFallback(`${base}.${fieldName}_${option.value}`) ||
    translationWithFallback(`${base}.${fieldName}s.${option.value}`) ||
    option.label ||
    option.name ||
    option.value
  );
}

export function fieldType(schema = {}) {
  return schema.type || "string";
}

export function fieldControl(schema = {}) {
  const ui = fieldUi(schema);

  if (ui.control) {
    return ui.control;
  }

  switch (fieldType(schema)) {
    case "boolean":
      return "boolean";
    case "icon":
      return "icon";
    case "options":
      return "select";
    case "collection":
      return "collection";
    case "notice":
      return "notice";
    case "credential":
      return "credential";
    default:
      return "input";
  }
}

export function fieldSupportsExpression(schema = {}) {
  const ui = fieldUi(schema);

  if (Object.hasOwn(ui, "expression")) {
    return Boolean(ui.expression);
  }

  if (Object.hasOwn(schema, "expression")) {
    return Boolean(schema.expression);
  }

  return ["string", "integer", "number", "icon"].includes(fieldType(schema));
}

export function fieldRows(schema = {}) {
  const ui = fieldUi(schema);
  return ui.rows || 4;
}

export function fieldShowDescription(schema = {}) {
  return fieldUi(schema).show_description !== false;
}

export function fieldShowLabel(schema = {}) {
  return fieldUi(schema).show_label !== false;
}

export function fieldFormat(schema = {}) {
  return fieldUi(schema).format || schema.format || "full";
}

export function fieldInputType(schema = {}) {
  const ui = fieldUi(schema);
  if (ui.control === "password") {
    return "password";
  }
  return ["integer", "number"].includes(fieldType(schema)) ? "number" : "text";
}

export function fieldValue(schema = {}, value) {
  if (value !== undefined && value !== null) {
    return value;
  }

  if (schema.default !== undefined) {
    return cloneValue(schema.default);
  }

  return cloneValue(fallbackValueForType(fieldType(schema)));
}

export function emptyCollectionItem(itemSchema = {}, extraItemSchema = {}) {
  return Object.fromEntries(
    Object.entries({ ...itemSchema, ...extraItemSchema }).map(
      ([name, schema]) => [name, fieldValue(schema)]
    )
  );
}

export function fieldVisible(schema = {}, configuration = {}) {
  if (fieldUi(schema).hidden) {
    return false;
  }

  const rules = schema.visible_if || fieldUi(schema).visible_if;

  if (!rules) {
    return true;
  }

  return Object.entries(rules).every(([fieldName, expected]) => {
    const allowedValues = Array.isArray(expected) ? expected : [expected];
    return allowedValues.includes(configuration[fieldName]);
  });
}
