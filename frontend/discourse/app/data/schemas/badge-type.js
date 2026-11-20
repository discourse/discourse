import { attrs, withDefaults } from "./helpers.js";

/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const BadgeTypeSchema = withDefaults({
  type: "badge-type",
  fields: [...attrs("name", "sort_order")],
});
