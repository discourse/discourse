import { attrs, withDefaults } from "./helpers";

// `site` is stamped on at runtime by `Site.create` so `isDefault` can compare
// against `this.site.default_archetype`.
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const ArchetypeSchema = withDefaults({
  type: "archetype",
  fields: [...attrs("name", "options", "site")],
});
