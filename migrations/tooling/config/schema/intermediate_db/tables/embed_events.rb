# frozen_string_literal: true

# Event embeds. `event_id` is the source `original_id` of an event converted by its
# own step (the `events` table). The importer renders that event into the owner's
# markdown once it exists. `placeholder` holds the token spliced into the owner's
# markdown; see `Migrations::Placeholder`. `owner_type`/`owner_id` name that owning
# record — in practice always a post, the only place Discourse renders an event.
Migrations::Tooling::Schema.table :embed_events do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :event_id, :numeric

  index :owner_type, :owner_id
end
