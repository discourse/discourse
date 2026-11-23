import type { LegacyResourceSchema } from "@warp-drive/core/types/schema/fields";
import { attrs, withDefaults } from "./helpers.ts";

// TagGroup stays on the legacy `Store` + `RestAdapter` path (admin CRUD via
// `record.save()` / `record.destroyRecord()`). Schema only powers the
// wrapper's field forwarders. `tags` / `parent_tag` / `permissions` are
// opaque payloads.
export const TagGroupSchema: LegacyResourceSchema = withDefaults({
  type: "tag-group",
  fields: [
    ...attrs("name", "tags", "parent_tag", "one_per_topic", "permissions"),
  ],
});
