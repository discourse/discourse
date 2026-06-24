# frozen_string_literal: true

# Link embeds. These point at no Discourse entity; they are just text the importer
# rewrites once the `original_id -> discourse_id` maps exist. `target_topic_id` and
# `target_post_id` hold the source `original_id` of the linked entity, if any.
# `placeholder` holds the token put in `post.raw`; see `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_links do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :url, :text
  add_column :text, :text
  add_column :target_topic_id, :numeric
  add_column :target_post_id, :numeric

  index :post_id
end
