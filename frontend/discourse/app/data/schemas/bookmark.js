import { attrs, withDefaults } from "./helpers";

// `user` is opaque — wrapped as a `User` instance in `Bookmark.create` rather
// than treated as a relationship (User isn't migrated yet).
//
// `currentUser` and `topicStatus` are not schema fields — they're set as own
// properties on the wrapper by `Bookmark.create` and the user-activity
// controller's `transform`, respectively.
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const BookmarkSchema = withDefaults({
  type: "bookmark",
  fields: [
    ...attrs(
      "name",
      "created_at",
      "updated_at",
      "reminder_at",
      "reminder_at_ics_start",
      "reminder_at_ics_end",
      "pinned",
      "title",
      "fancy_title",
      "fancy_title_localized",
      "locale",
      "excerpt",
      "bookmarkable_id",
      "bookmarkable_type",
      "bookmarkable_url",
      "topic_id",
      "linked_post_number",
      "deleted",
      "hidden",
      "category_id",
      "closed",
      "archived",
      "archetype",
      "highest_post_number",
      "bumped_at",
      "slug",
      "tags",
      "tags_descriptions",
      "truncated",
      "post_id",
      // Only on bookmarks embedded in topic-view payloads (TopicViewBookmarkSerializer).
      "post_number",
      "last_read_post_number",
      "is_warning",
      "invisible",
      "user",
      // Local-only — set by `Bookmark.createFor` and `BookmarkFormData.saveData`.
      "auto_delete_preference",
      "user_id"
    ),
  ],
});
