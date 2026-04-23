import { fieldVisible } from "./property-engine";

function isBlank(value) {
  if (value === undefined || value === null) {
    return true;
  }
  if (typeof value === "string") {
    return value.trim() === "";
  }
  if (Array.isArray(value)) {
    return value.length === 0;
  }
  return false;
}

function itemSchemaFor(field) {
  return {
    ...(field.item_schema || {}),
    ...(field.extra_item_schema || {}),
  };
}

function applyDefaults(schema, config) {
  const effective = { ...(config || {}) };
  for (const [name, field] of Object.entries(schema)) {
    if (effective[name] == null && field.default !== undefined) {
      effective[name] = field.default;
    }
  }
  return effective;
}

function walk(schema, config, pathPrefix, issues) {
  const effective = applyDefaults(schema, config);

  for (const [name, field] of Object.entries(schema)) {
    if (!fieldVisible(field, effective)) {
      continue;
    }

    const path = pathPrefix ? `${pathPrefix}.${name}` : name;
    const value = effective[name];

    if (field.required && isBlank(value)) {
      issues.push({ path, name, message: "required" });
    }

    if (field.type === "collection" && Array.isArray(value)) {
      const inner = itemSchemaFor(field);
      value.forEach((item, index) => {
        walk(inner, item || {}, `${path}.${index}`, issues);
      });
    }
  }
}

export default function getNodeIssues(configuration, propertySchema) {
  if (!propertySchema) {
    return [];
  }
  const issues = [];
  walk(propertySchema, configuration || {}, "", issues);
  return issues;
}
