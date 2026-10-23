import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

// Loaded via `/tag/:id/info.json` (DetailedTagSerializer). Schema covers the
// fields the legacy model exposed via `@tracked` / `@autoTrackedArray`.
export const TagInfoSchema: LegacyResourceSchema = withDefaults({
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
