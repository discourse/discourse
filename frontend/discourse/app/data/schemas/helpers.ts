import type {
  LegacyAttributeField,
  LegacyBelongsToField,
  LegacyHasManyField,
} from "@warp-drive/core/types/schema/fields";

// Schemas annotate their export as `LegacyResourceSchema` so the emitted
// `.d.ts` doesn't anchor through pnpm's `.pnpm/...` path (TS2883).
export { withDefaults } from "@warp-drive/legacy/model/migration-support";

export function attrs(...names: string[]): LegacyAttributeField[] {
  return names.map((name) => ({ kind: "attribute", name }));
}

export function belongsTo(name: string, type: string): LegacyBelongsToField {
  return {
    kind: "belongsTo",
    name,
    type,
    options: { async: false, inverse: null },
  };
}

export function hasMany(name: string, type: string): LegacyHasManyField {
  return { ...belongsTo(name, type), kind: "hasMany" };
}
