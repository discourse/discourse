import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "../helpers.js";

// Mirrors `GroupResource` (app/resources/group_resource.rb).
export const GroupsSchema: LegacyResourceSchema = withDefaults({
  type: "groups",
  fields: attrs("name"),
});
