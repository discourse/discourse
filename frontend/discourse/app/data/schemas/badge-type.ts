import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

export const BadgeTypeSchema: LegacyResourceSchema = withDefaults({
  type: "badge-type",
  fields: [...attrs("name", "sort_order")],
});
