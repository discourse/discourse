import { attrs, withDefaults } from "./helpers";

// Tag stays on the legacy `Store` + `RestAdapter` path; this schema only
// powers the wrapper's field forwarders. `target_tag` / `localizations` are
// opaque (their target models aren't migrated).
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const TagSchema = withDefaults({
  type: "tag",
  fields: [
    ...attrs(
      "name",
      "slug",
      "description",
      "text",
      "count",
      "pm_count",
      "pm_only",
      "topic_count",
      "staff",
      "target_tag",
      "localizations"
    ),
  ],
});
