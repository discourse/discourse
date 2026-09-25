// Mirrors `withDefaults` from `@warp-drive/legacy/model/migration-support`, so
// models can define their schema without loading the store's code.
const LEGACY_FIELDS = [
  "_createSnapshot",
  "adapterError",
  "belongsTo",
  "changedAttributes",
  "constructor",
  "currentState",
  "deleteRecord",
  "destroyRecord",
  "dirtyType",
  "errors",
  "hasDirtyAttributes",
  "hasMany",
  "isDeleted",
  "isEmpty",
  "isError",
  "isLoaded",
  "isLoading",
  "isNew",
  "isSaving",
  "isValid",
  "reload",
  "rollbackAttributes",
  "save",
  "serialize",
  "unloadRecord",
];

function localBoolean(name) {
  return {
    name,
    kind: "@local",
    type: "boolean",
    options: { defaultValue: false },
  };
}

export function withDefaults(schema) {
  schema.legacy = true;
  schema.identity = { kind: "@id", name: "id" };
  for (const field of LEGACY_FIELDS) {
    schema.fields.push({ type: "@legacy", name: field, kind: "derived" });
  }
  schema.fields.push(localBoolean("_isReloading"));
  schema.fields.push(localBoolean("isDestroying"));
  schema.fields.push(localBoolean("isDestroyed"));
  schema.objectExtensions = schema.objectExtensions || [];
  schema.objectExtensions.push("deprecated-model-behaviors");
  return schema;
}

export function attrs(...names) {
  return names.map((name) => ({ kind: "attribute", name }));
}

export function belongsTo(name, type) {
  return {
    kind: "belongsTo",
    name,
    type,
    options: { async: false, inverse: null },
  };
}
