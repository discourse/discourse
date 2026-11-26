import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

export const BadgeGroupingSchema: LegacyResourceSchema = withDefaults({
  type: "badge-grouping",
  fields: [
    ...attrs(
      "name",
      "description",
      "position",
      "system",
      // Server doesn't ship `displayName` — populated at normalize time via i18n.
      "displayName"
    ),
  ],
});
