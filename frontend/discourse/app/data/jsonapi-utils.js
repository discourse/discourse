import { recordExtraAttributes } from "discourse/data/extra-attributes";

// Keeps the schema-declared attributes of `raw`. Pass `identity` to retain the
// remaining keys as extra attributes for that resource rather than dropping
// them — see `extra-attributes.js`.
export function pickSchemaAttributes(raw, schema, identity) {
  const out = {};
  const declared = new Set();

  if (schema.identity?.name) {
    declared.add(schema.identity.name);
  }

  for (const field of schema.fields ?? []) {
    declared.add(field.name);

    if (field.kind !== "attribute") {
      continue;
    }
    if (field.name in raw) {
      out[field.name] = raw[field.name];
    }
  }

  if (identity) {
    const extras = {};
    for (const [name, value] of Object.entries(raw)) {
      if (!declared.has(name)) {
        extras[name] = value;
      }
    }
    recordExtraAttributes(identity.type, identity.id, extras);
  }

  return out;
}

export function indexIncluded(included) {
  return new Set(included.map((r) => `${r.type}:${r.id}`));
}

// Add a relationship pointer only when the related resource is in
// `includedIds` — referencing a missing identity logs a cache-validator
// warning and leaves a dangling pointer on cold loads.
export function maybeRelate(relationships, name, includedIds, type, id) {
  if (id == null || !includedIds.has(`${type}:${id}`)) {
    return;
  }
  relationships[name] = { data: { type, id: String(id) } };
}
