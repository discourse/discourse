import {
  fieldType,
  fieldVisible,
  fixedCollectionGroups,
  fixedCollectionRows,
  normalizePropertyOptions,
} from "./property-engine";

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

function fixedCollectionItemSchema(group) {
  return group.values || {};
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

    const type = fieldType(field);

    if (
      type === "collection" &&
      value &&
      typeof value === "object" &&
      !Array.isArray(value)
    ) {
      normalizePropertyOptions(field.options || []).forEach((option) => {
        if (Object.hasOwn(value, option.name)) {
          walk({ [option.name]: option }, value, path, issues);
        }
      });
    } else if (
      type === "fixed_collection" &&
      value &&
      typeof value === "object"
    ) {
      fixedCollectionGroups(field).forEach((group) => {
        const rows = fixedCollectionRows(value, group.name);
        if (field.required && isBlank(rows)) {
          issues.push({
            path: `${path}.${group.name}`,
            name,
            message: "required",
          });
        }
        rows.forEach((item, index) => {
          walk(
            fixedCollectionItemSchema(group),
            item || {},
            `${path}.${group.name}.${index}`,
            issues
          );
        });
      });
    } else if (
      type === "assignment_collection" &&
      value &&
      typeof value === "object"
    ) {
      const assignments = fixedCollectionRows(value, "assignments");
      if (field.required && isBlank(assignments)) {
        issues.push({ path: `${path}.assignments`, name, message: "required" });
      }
      assignments.forEach((item, index) => {
        walk(
          {
            name: { type: "string", required: true },
            type: { type: "options", required: true },
            value: { type: "string", required: true },
          },
          item || {},
          `${path}.assignments.${index}`,
          issues
        );
      });
    } else if (field.type === "collection" && Array.isArray(value)) {
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
