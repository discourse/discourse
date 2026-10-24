import { attrs, withDefaults } from "../helpers.js";

// Mirrors `GroupResource` (app/resources/group_resource.rb).
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const GroupsSchema = withDefaults({
  type: "groups",
  fields: attrs("name"),
});
