/**
 * @import {
 *   LegacyAttributeField,
 *   LegacyBelongsToField,
 *   LegacyHasManyField,
 * } from "@warp-drive/core/types/schema/fields"
 */

// Schemas annotate their export as `LegacyResourceSchema` so the emitted
// `.d.ts` doesn't anchor through pnpm's `.pnpm/...` path (TS2883).
export { withDefaults } from "@warp-drive/legacy/model/migration-support";

/**
 * @param {...string} names
 * @returns {LegacyAttributeField[]}
 */
export function attrs(...names) {
  return names.map((name) => ({ kind: "attribute", name }));
}

/**
 * @param {string} name
 * @param {string} type
 * @returns {LegacyBelongsToField}
 */
export function belongsTo(name, type) {
  return {
    kind: "belongsTo",
    name,
    type,
    options: { async: false, inverse: null },
  };
}

/**
 * @param {string} name
 * @param {string} type
 * @returns {LegacyHasManyField}
 */
export function hasMany(name, type) {
  return { ...belongsTo(name, type), kind: "hasMany" };
}
