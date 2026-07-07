# frozen_string_literal: true

# Link embeds. These point at no Discourse entity; they are just text the importer
# rewrites once the `original_id -> discourse_id` maps exist. `target_type`/`target_id`
# hold the kind and source `original_id` of the linked entity, if any. `placeholder`
# holds the token spliced into the owner's markdown (a post body today, a user bio
# etc. later); see `Migrations::Placeholder`. `owner_type`/`owner_id` name that
# owning record.
Migrations::Tooling::Schema.table :embed_links do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :url, :text
  add_column :text, :text
  add_column :target_type, :integer, enum: :link_target
  add_column :target_id, :numeric

  index :owner_type, :owner_id
end
