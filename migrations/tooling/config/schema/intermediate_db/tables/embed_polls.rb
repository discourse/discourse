# frozen_string_literal: true

# Poll embeds. `poll_id` is the source `original_id` of a poll converted by its own
# step (the `polls` table). The importer renders that poll into the owner's markdown
# once it exists. `placeholder` holds the token spliced into the owner's markdown;
# see `Migrations::Placeholder`. `owner_type`/`owner_id` name that owning record —
# in practice always a post, the only place Discourse renders a poll.
Migrations::Tooling::Schema.table :embed_polls do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :poll_id, :numeric

  index :owner_type, :owner_id
end
