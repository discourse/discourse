import { attrs, withDefaults } from "./helpers";

// Loaded via `/tag/:id/info.json` (DetailedTagSerializer). Schema covers the
// fields the legacy model exposed via `@tracked` / `@autoTrackedArray`.
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const TagInfoSchema = withDefaults({
  type: "tag-info",
  fields: [
    ...attrs(
      "name",
      "slug",
      "description",
      "topic_count",
      "staff",
      "category_restricted",
      "categories",
      "localizations",
      "synonyms",
      "tag_group_names"
    ),
  ],
});
