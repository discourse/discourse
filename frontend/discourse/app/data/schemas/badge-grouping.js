import { attrs, withDefaults } from "./helpers.js";

/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const BadgeGroupingSchema = withDefaults({
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
