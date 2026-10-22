import { attrs, withDefaults } from "../helpers.js";

// Mirrors `UserResource` (app/resources/user_resource.rb).
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const UsersSchema = withDefaults({
  type: "users",
  fields: attrs("username", "avatarTemplate"),
});
