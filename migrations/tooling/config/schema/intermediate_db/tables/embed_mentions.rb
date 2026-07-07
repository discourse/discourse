# frozen_string_literal: true

# `@mention` embeds. These point at no Discourse entity; they are just text the
# importer rewrites once the `original_id -> discourse_id` maps exist. `mention_type`
# is one of `user`, `group`, `here` or `all`. `target_id` holds the source
# `original_id` of the mentioned user or group (nil for `here` and `all`).
# `placeholder` holds the token spliced into the owner's markdown (a post body today,
# a user bio etc. later); see `Migrations::Placeholder`. `owner_type`/`owner_id` name
# that owning record.
Migrations::Tooling::Schema.table :embed_mentions do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :mention_type, :text
  add_column :target_id, :numeric
  add_column :name, :text

  index :owner_type, :owner_id
end
