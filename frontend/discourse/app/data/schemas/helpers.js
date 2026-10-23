// Schemas annotate their export with `@type {LegacyResourceSchema}` so the
// emitted `.d.ts` doesn't anchor through pnpm's `.pnpm/...` path (TS2883).
export { withDefaults } from "@warp-drive/legacy/model/migration-support";

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
