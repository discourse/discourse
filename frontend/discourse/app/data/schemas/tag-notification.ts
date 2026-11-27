import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

// Identity key for the legacy `Store.update` URL routing is `name`, not `id`
// — the model sets `primaryKey = "name"` so `/tag/${name}/notifications.json`
// resolves correctly when the user changes the notification level.
export const TagNotificationSchema: LegacyResourceSchema = withDefaults({
  type: "tag-notification",
  fields: [...attrs("name", "notification_level")],
});
