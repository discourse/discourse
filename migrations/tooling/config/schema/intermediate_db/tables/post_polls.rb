# frozen_string_literal: true

# Poll embeds. `poll_id` is the source `original_id` of a poll converted by its own
# step (the `polls` table). The importer renders that poll into the post body once
# it exists. `placeholder` holds the token put in `post.raw`; see
# `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_polls do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :poll_id, :numeric

  index :post_id
end
