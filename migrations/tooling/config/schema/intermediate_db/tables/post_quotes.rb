# frozen_string_literal: true

# `[quote]` embeds. These point at no Discourse entity; they are just text the
# importer rewrites once the `original_id -> discourse_id` maps exist. `placeholder`
# holds the token put in `post.raw`; see `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_quotes do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :quoted_post_id, :numeric
  add_column :quoted_user_id, :numeric
  add_column :quoted_username, :text

  index :post_id
end
