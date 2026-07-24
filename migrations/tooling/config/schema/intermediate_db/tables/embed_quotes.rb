# frozen_string_literal: true

# `[quote]` embeds. These point at no Discourse entity; they are just text the
# importer rewrites once the `original_id -> discourse_id` maps exist. `placeholder`
# holds the token spliced into the owner's markdown (a post body today, a user bio
# etc. later); see `Migrations::Placeholder`. `owner_type`/`owner_id` name that
# owning record. `quoted_username` and `quoted_name` are the source's fallback
# display, used when the quoted user can't be mapped to a Discourse user. The
# username doubles as the lookup key: when `quoted_user_id` is nil, the importer
# resolves it to the user's `original_id` (in memory, never written back).
#
# The quoted post is identified either by its source `original_id` (`quoted_post_id`,
# filled by converters that know it) or by the source coordinates the attribution
# carries (`quoted_topic_id` + `quoted_post_number`, the source's own numbering).
# The importer resolves the coordinates to a `quoted_post_id` before rendering.
Migrations::Tooling::Schema.table :embed_quotes do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :quoted_post_id, :numeric
  add_column :quoted_topic_id, :numeric
  add_column :quoted_post_number, :integer
  add_column :quoted_user_id, :numeric
  add_column :quoted_username, :text
  add_column :quoted_name, :text

  index :owner_type, :owner_id
end
