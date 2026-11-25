import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

export const TagSettingsSchema: LegacyResourceSchema = withDefaults({
  type: "tag-settings",
  fields: [
    ...attrs(
      "name",
      "locale",
      "slug",
      "description",
      "synonyms",
      "tag_group_names",
      "tag_groups",
      "category_restricted",
      "can_edit",
      "can_admin",
      "categories",
      "localizations"
    ),
  ],
});
