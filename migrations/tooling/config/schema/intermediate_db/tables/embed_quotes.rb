# frozen_string_literal: true

# `[quote]` embeds. These point at no Discourse entity; they are just text the
# importer rewrites once the `original_id -> discourse_id` maps exist. `placeholder`
# holds the token spliced into the owner's markdown (a post body today, a user bio
# etc. later); see `Migrations::Placeholder`. `owner_type`/`owner_id` name that
# owning record. `quoted_username` and `quoted_name` are the source's fallback
# display, used when the quoted user can't be mapped to a Discourse user.
Migrations::Tooling::Schema.table :embed_quotes do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :quoted_post_id, :numeric
  add_column :quoted_user_id, :numeric
  add_column :quoted_username, :text
  add_column :quoted_name, :text

  index :owner_type, :owner_id
end
