import moment from "moment";
import { i18n } from "discourse-i18n";
import {
  nodeTypePropertyI18nPrefix,
  nodeTypePropertyI18nScope,
  translatedOrNull,
} from "./node-types";

function cloneValue(value) {
  return value === undefined ? undefined : structuredClone(value);
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

function translationKeyWithFallback(keys = []) {
  return keys.find((key) => translatedOrNull(key) !== null) || null;
}

function nodeMetadata(nodeDefinitionOrType) {
  return nodeDefinitionOrType?.metadata || {};
}

export function findNodeType(nodeTypes, nodeType) {
  return (
    nodeTypes?.find((definition) => definition.identifier === nodeType) || null
  );
}

export function getPropertySchema(nodeTypes, nodeType, typeVersion = null) {
  const definition = findNodeType(nodeTypes, nodeType);

  if (!definition) {
    return {};
  }

  if (typeVersion && definition.property_schema_versions?.[typeVersion]) {
    return definition.property_schema_versions[typeVersion];
  }

  return definition.property_schema || {};
}

export function normalizeSchema(schema = {}) {
  return Object.entries(schema).map(([name, field]) => ({
    name,
    ...field,
  }));
}

export function propertyI18nPrefix(nodeDefinitionOrType) {
  return (
    nodeTypePropertyI18nPrefix(nodeDefinitionOrType) ||
    nodeMetadata(nodeDefinitionOrType).i18n_prefix
  );
}

export function propertyScope(nodeDefinitionOrType) {
  return nodeTypePropertyI18nScope(nodeDefinitionOrType);
}

function i18nBase(nodeDefinitionOrType) {
  return `${propertyI18nPrefix(nodeDefinitionOrType)}.${propertyScope(nodeDefinitionOrType)}`;
}

export function propertyLabel(nodeDefinitionOrType, fieldName) {
  const base = i18nBase(nodeDefinitionOrType);

  return (
    translatedOrNull(`${base}.${fieldName}`) ||
    translatedOrNull(`${base}.${fieldName}.title`) ||
    humanize(fieldName)
  );
}

export function propertyDescription(nodeDefinitionOrType, fieldName) {
  return translatedOrNull(
    `${i18nBase(nodeDefinitionOrType)}.${fieldName}_description`
  );
}

export function propertyPlaceholder(nodeDefinitionOrType, fieldName) {
  return translatedOrNull(
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
    translatedOrNull(`${i18nBase(nodeDefinitionOrType)}.add_${singular}`) ||
    i18n("discourse_workflows.property_engine.add_item")
  );
}

export function formatOptionValue(value, format) {
  if (format === "hour_of_day") {
    return moment().hour(value).minute(0).format("LT");
  }
  if (format === "weekday") {
    return moment().day(value).format("dddd");
  }
  return String(value);
}

export function normalizeOptions(options = []) {
  return options.map((option) =>
    typeof option === "object" ? option : { value: option }
  );
}

export function propertyOptionLabel(nodeDefinitionOrType, fieldName, option) {
  const base = i18nBase(nodeDefinitionOrType);

  return (
    translatedOrNull(`${base}.${fieldName}_${option.value}`) ||
    translatedOrNull(`${base}.${fieldName}s.${option.value}`) ||
    option.label ||
    option.name ||
    option.value
  );
}

export function fieldType(schema = {}) {
  return schema.type || "string";
}

const TYPE_TO_CONTROL = {
  boolean: "boolean",
  icon: "icon",
  options: "select",
  collection: "collection",
  notice: "notice",
  credential: "credential",
};

export function fieldControl(schema = {}) {
  return (
    fieldUi(schema).control || TYPE_TO_CONTROL[fieldType(schema)] || "input"
  );
}

export function fieldSupportsExpression(schema = {}) {
  const ui = fieldUi(schema);

  if (Object.hasOwn(ui, "expression")) {
    return Boolean(ui.expression);
  }

  if (Object.hasOwn(schema, "expression")) {
    return Boolean(schema.expression);
  }

  return ["string", "integer", "icon"].includes(fieldType(schema));
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
  return fieldType(schema) === "integer" ? "number" : "text";
}

export function fieldValue(schema = {}, value) {
  return (
    value ??
    cloneValue(schema.default ?? fallbackValueForType(fieldType(schema)))
  );
}

export function emptyCollectionItem(itemSchema = {}, extraItemSchema = {}) {
  return Object.fromEntries(
    Object.entries({ ...itemSchema, ...extraItemSchema }).map(
      ([name, schema]) => [name, fieldValue(schema)]
    )
  );
}

export function isExpression(value) {
  return typeof value === "string" && value.startsWith("=");
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
    const value = configuration[fieldName];
    if (expected === "$empty") {
      return isEmptyValue(value);
    }
    const allowedValues = Array.isArray(expected) ? expected : [expected];
    return allowedValues.includes(value);
  });
}

function isEmptyValue(value) {
  if (value == null || value === "") {
    return true;
  }
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  return false;
}
