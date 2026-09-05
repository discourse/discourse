import { attrs, withDefaults } from "./helpers";

/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const TagSettingsSchema = withDefaults({
  type: "tag-settings",
  fields: [
    ...attrs(
      "name",
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
