import { attrs, belongsTo, withDefaults } from "./helpers";

// `user` / `granted_by` / `topic` are opaque attributes rather than relations
// — those models aren't migrated yet; LegacyMode would throw on every unknown
// field read against a cached `user` / `topic` record.
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const UserBadgeSchema = withDefaults({
  type: "user-badge",
  fields: [
    ...attrs(
      "granted_at",
      "created_at",
      "count",
      "post_id",
      "post_number",
      "grouping_position",
      "topic_id",
      "topic_title",
      "is_favorite",
      "can_favorite",
      "user",
      "granted_by",
      "topic"
    ),
    belongsTo("badge", "badge"),
  ],
});
