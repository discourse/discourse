import { attrs, withDefaults } from "./helpers";

// TagGroup stays on the legacy `Store` + `RestAdapter` path (admin CRUD via
// `record.save()` / `record.destroyRecord()`). Schema only powers the
// wrapper's field forwarders. `tags` / `parent_tag` / `permissions` are
// opaque payloads.
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const TagGroupSchema = withDefaults({
  type: "tag-group",
  fields: [
    ...attrs("name", "tags", "parent_tag", "one_per_topic", "permissions"),
  ],
});
