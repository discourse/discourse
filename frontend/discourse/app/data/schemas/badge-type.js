import { attrs, withDefaults } from "./helpers";

/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const BadgeTypeSchema = withDefaults({
  type: "badge-type",
  fields: [...attrs("name", "sort_order")],
});
