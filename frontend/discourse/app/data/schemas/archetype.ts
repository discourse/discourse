import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

// `site` is stamped on at runtime by `Site.create` so `isDefault` can compare
// against `this.site.default_archetype`.
export const ArchetypeSchema: LegacyResourceSchema = withDefaults({
  type: "archetype",
  fields: [...attrs("name", "options", "site")],
});
