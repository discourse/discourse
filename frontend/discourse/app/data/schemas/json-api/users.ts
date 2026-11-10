import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "../helpers.js";

// Mirrors `UserResource` (app/resources/user_resource.rb).
export const UsersSchema: LegacyResourceSchema = withDefaults({
  type: "users",
  fields: attrs("username", "avatarTemplate"),
});
