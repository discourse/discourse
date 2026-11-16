import {
  attrs,
  belongsTo,
  hasMany,
  withDefaults,
} from "discourse/data/schemas/helpers";

// Mirrors `QueryResource` (app/resources/discourse_data_explorer/query_resource.rb).
/** @type {import("@warp-drive/core/types/schema/fields").LegacyResourceSchema} */
export const QueriesSchema = withDefaults({
  type: "queries",
  fields: [
    ...attrs(
      "name",
      "description",
      "sql",
      "paramInfo",
      "isDefault",
      "createdAt",
      "lastRunAt",
      "tags",
      "automaticTags",
      "dashboardMountable",
      "dashboardMounted"
    ),
    belongsTo("user", "users"),
    hasMany("groups", "groups"),
  ],
});
