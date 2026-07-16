import moment from "moment";
import { i18n } from "discourse-i18n";
import {
  nodeTypeI18nPrefix,
  nodeTypeI18nScope,
  resolveNodeTypeVersion,
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
    case "fixed_collection":
      return {};
    case "assignment_collection":
      return { assignments: [] };
    case "array":
    case "multi_options":
      return [];
    default:
      return "";
  }
}

function translationKeyWithFallback(keys = []) {
  return keys.find((key) => translatedOrNull(key) !== null) || null;
}

export function localeKeyPart(value) {
  return String(value)
    .replace(/([a-z0-9])([A-Z])/g, "$1_$2")
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1_$2")
    .replace(/[\s-]+/g, "_")
    .toLowerCase();
}

export function findNodeType(nodeTypes, nodeType) {
  return (
    nodeTypes?.find(
      (definition) =>
        definition.name === nodeType || definition.identifier === nodeType
    ) || null
  );
}

export function getPropertySchema(nodeTypes, nodeType, typeVersion = null) {
  const definition = findNodeType(nodeTypes, nodeType);

  if (!definition) {
    return {};
  }

  const versionedDefinition = resolveNodeTypeVersion(definition, typeVersion);
  if (!versionedDefinition) {
    return {};
  }

  return versionedDefinition.properties || definition.properties || {};
}

export function normalizeSchema(schema = {}) {
  return Object.entries(schema).map(([name, field]) => ({
    name,
    ...field,
  }));
}

export function i18nPrefix(nodeDefinitionOrType) {
  return nodeTypeI18nPrefix(nodeDefinitionOrType);
}

export function i18nScope(nodeDefinitionOrType) {
  return nodeTypeI18nScope(nodeDefinitionOrType);
}

function i18nBase(nodeDefinitionOrType) {
  return `${i18nPrefix(nodeDefinitionOrType)}.${i18nScope(nodeDefinitionOrType)}`;
}

export function propertyLabel(nodeDefinitionOrType, fieldName) {
  const base = i18nBase(nodeDefinitionOrType);
  const labelKey = localeKeyPart(fieldName);

  return (
    translatedOrNull(`${base}.${labelKey}`) ||
    translatedOrNull(`${base}.${labelKey}.title`) ||
    humanize(fieldName)
  );
}

export function propertyDescription(nodeDefinitionOrType, fieldName) {
  return translatedOrNull(
    `${i18nBase(nodeDefinitionOrType)}.${localeKeyPart(fieldName)}_description`
  );
}

export function propertyTooltip(nodeDefinitionOrType, fieldName) {
  return translatedOrNull(
    `${i18nBase(nodeDefinitionOrType)}.${localeKeyPart(fieldName)}_tooltip`
  );
}

export function propertyPlaceholder(nodeDefinitionOrType, fieldName) {
  return translatedOrNull(
    `${i18nBase(nodeDefinitionOrType)}.${localeKeyPart(fieldName)}_placeholder`
  );
}

function dynamicValueKey(schema = {}, fieldName) {
  const ui = fieldUi(schema);

  if (ui.dynamic_value) {
    return ui.dynamic_value;
  }

  switch (fieldControl(schema)) {
    case "actor":
      return "username";
    case "category":
      return "category_id";
    case "data_table_column_select":
      return "column_name";
    case "data_table_select":
      return "data_table_id";
    case "group_select":
      return schema.control_options?.value_property === "name"
        ? "group_names"
        : "group_id";
    case "tags":
      return "tag_names";
    case "user":
      return ui.multiple ? "usernames" : "username";
    case "user_or_group":
      return "user_or_group_name";
    case "select":
      return "option_value";
    default:
      break;
  }

  if (fieldName?.endsWith("_username")) {
    return "username";
  }

  if (fieldName?.endsWith("_id")) {
    return "id";
  }

  switch (fieldType(schema)) {
    case "boolean":
      return "boolean";
    case "float":
    case "integer":
    case "number":
      return "number";
    default:
      break;
  }

  return null;
}

export function propertyDynamicValueHint(
  nodeDefinitionOrType,
  fieldName,
  schema = {}
) {
  const base = i18nBase(nodeDefinitionOrType);
  const labelKey = localeKeyPart(fieldName);
  const fieldHint = translatedOrNull(`${base}.${labelKey}_dynamic_hint`);

  if (fieldHint) {
    return fieldHint;
  }

  const valueKey = dynamicValueKey(schema, fieldName);

  if (!valueKey) {
    return null;
  }

  const value =
    translatedOrNull(
      `discourse_workflows.property_engine.dynamic_values.${localeKeyPart(
        valueKey
      )}`
    ) || humanize(valueKey);

  return i18n("discourse_workflows.property_engine.dynamic_hint", { value });
}

export function propertySelectNoneKey(nodeDefinitionOrType, fieldName) {
  const base = i18nBase(nodeDefinitionOrType);
  const key = localeKeyPart(fieldName);
  const selectField = key.replace(/_id$/, "");

  return translationKeyWithFallback([
    `${base}.select_${selectField}`,
    `${base}.${key}_placeholder`,
  ]);
}

export function collectionAddLabel(
  nodeDefinitionOrType,
  fieldName,
  schema = {}
) {
  const override = fieldUi(schema).singular_name;
  const singular =
    override || (fieldName.endsWith("s") ? fieldName.slice(0, -1) : fieldName);

  return (
    translatedOrNull(
      `${i18nBase(nodeDefinitionOrType)}.add_${localeKeyPart(singular)}`
    ) || i18n("discourse_workflows.property_engine.add_item")
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

export function normalizePropertyOptions(options = []) {
  return options.map((option) => ({
    name: option.name || option.value,
    ...option,
  }));
}

export function fixedCollectionGroups(schema = {}) {
  return normalizePropertyOptions(schema.options || []);
}

export function fixedCollectionGroup(schema = {}) {
  return fixedCollectionGroups(schema)[0] || { name: "values", values: {} };
}

export function fixedCollectionGroupMultiple(group = {}, schema = {}) {
  const type_options = schema.type_options || {};
  if (Object.hasOwn(type_options, "multiple_values")) {
    return Boolean(type_options.multiple_values);
  }
  if (Object.hasOwn(group, "multiple_values")) {
    return Boolean(group.multiple_values);
  }
  return true;
}

export function fixedCollectionRows(value, groupName = "values") {
  if (Array.isArray(value)) {
    return value;
  }
  const groupValue = value?.[groupName];
  if (Array.isArray(groupValue)) {
    return groupValue;
  }
  if (groupValue && typeof groupValue === "object") {
    return [groupValue];
  }
  return [];
}

export function fieldType(schema = {}) {
  return schema.type || "string";
}

export function propertyOptionLabel(nodeDefinitionOrType, fieldName, option) {
  const base = i18nBase(nodeDefinitionOrType);
  const key = localeKeyPart(fieldName);
  const valueKey = localeKeyPart(option.value);

  return (
    translatedOrNull(`${base}.${key}_${valueKey}`) ||
    translatedOrNull(`${base}.${key}s.${valueKey}`) ||
    (option.label_key ? translatedOrNull(option.label_key) : null) ||
    option.label ||
    option.name ||
    option.value
  );
}

const TYPE_TO_CONTROL = {
  boolean: "boolean",
  icon: "icon",
  options: "select",
  multi_options: "multi_combo_box",
  collection: "collection",
  fixed_collection: "fixed_collection",
  assignment_collection: "assignment_collection",
  notice: "notice",
  credential: "credential",
};

export function fieldControl(schema = {}) {
  return (
    fieldUi(schema).control || TYPE_TO_CONTROL[fieldType(schema)] || "input"
  );
}

export function fieldSupportsExpression(schema = {}) {
  if (schema.no_data_expression) {
    return false;
  }

  const ui = fieldUi(schema);

  if (Object.hasOwn(ui, "expression")) {
    return Boolean(ui.expression);
  }

  return ["string", "integer", "number", "float", "icon"].includes(
    fieldType(schema)
  );
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
  return ["integer", "float", "number"].includes(fieldType(schema))
    ? "number"
    : "text";
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

export function emptyFixedCollectionItem(group = {}) {
  return emptyCollectionItem(group.values || {});
}

export function isExpression(value) {
  return typeof value === "string" && value.startsWith("=");
}

export function credentialTypesForSlot(slot = {}) {
  return slot.credential_types || [slot.credential_type].filter(Boolean);
}

export function credentialSlotVisible(slot = {}, configuration = {}) {
  return fieldVisible(
    {
      display_options: slot.display_options,
    },
    configuration
  );
}

export function credentialSlotAnchorField(slot = {}) {
  const displayOptions = slot.display_options;
  const fields = new Set([
    ...Object.keys(displayOptions?.show || {}),
    ...Object.keys(displayOptions?.hide || {}),
  ]);
  return fields.size === 1 ? [...fields][0] : null;
}

export function fieldVisible(schema = {}, configuration = {}) {
  if (fieldUi(schema).hidden) {
    return false;
  }

  const display_options = schema.display_options;
  if (
    display_options?.show &&
    !matchesRules(display_options.show, configuration)
  ) {
    return false;
  }
  if (
    display_options?.hide &&
    matchesRules(display_options.hide, configuration)
  ) {
    return false;
  }

  return true;
}

function matchesRules(rules, configuration) {
  return Object.entries(rules).every(([fieldName, expected]) =>
    matchesRule(expected, configuration[fieldName])
  );
}

function matchesRule(expected, value) {
  if (!Array.isArray(expected)) {
    return matchesCondition(expected, value);
  }

  return expected.some((condition) => matchesCondition(condition, value));
}

function matchesCondition(condition, value) {
  const operator = condition?.condition;
  if (!operator) {
    return condition === value;
  }

  if (Object.hasOwn(operator, "not")) {
    return value !== operator.not;
  }

  if (Object.hasOwn(operator, "exists")) {
    return operator.exists ? !isEmptyValue(value) : isEmptyValue(value);
  }

  return false;
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
