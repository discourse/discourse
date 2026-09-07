import { attrs, withDefaults } from "./helpers";

// Identity key for the legacy `Store.update` URL routing is `name`, not `id`
// — the model sets `primaryKey = "name"` so `/tag/${name}/notifications.json`
// resolves correctly when the user changes the notification level.
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const TagNotificationSchema = withDefaults({
  type: "tag-notification",
  fields: [...attrs("name", "notification_level")],
});
