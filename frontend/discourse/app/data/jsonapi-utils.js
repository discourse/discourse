import { recordExtraAttributes } from "discourse/data/extra-attributes";

// Schemas are immutable module constants, so their field breakdown is computed
// once rather than per normalized record.
const schemaFields = new WeakMap();

function fieldsFor(schema) {
  let entry = schemaFields.get(schema);
  if (!entry) {
    const declared = new Set();
    const attributes = [];
    if (schema.identity?.name) {
      declared.add(schema.identity.name);
    }
    for (const field of schema.fields ?? []) {
      declared.add(field.name);
      if (field.kind === "attribute") {
        attributes.push(field.name);
      }
    }
    entry = { declared, attributes };
    schemaFields.set(schema, entry);
  }
  return entry;
}

// Builds the JSON:API resource object for `raw`: schema-declared attributes go
// on the resource, the remaining keys are retained as extra attributes (see
// `extra-attributes.js`). `id` defaults to `raw.id` — pass it explicitly for
// sub-resources whose identity comes from the parent.
export function resourceFrom(type, schema, raw, id = raw.id) {
  id = String(id);
  const { declared, attributes } = fieldsFor(schema);

  const out = {};
  for (const name of attributes) {
    if (name in raw) {
      out[name] = raw[name];
    }
  }

  const extras = {};
  for (const [name, value] of Object.entries(raw)) {
    if (!declared.has(name)) {
      extras[name] = value;
    }
  }
  recordExtraAttributes(type, id, extras);

  return { type, id, attributes: out };
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
