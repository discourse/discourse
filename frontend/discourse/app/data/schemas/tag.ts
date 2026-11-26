import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

// Tag stays on the legacy `Store` + `RestAdapter` path; this schema only
// powers the wrapper's field forwarders. `target_tag` / `localizations` are
// opaque (their target models aren't migrated).
export const TagSchema: LegacyResourceSchema = withDefaults({
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
