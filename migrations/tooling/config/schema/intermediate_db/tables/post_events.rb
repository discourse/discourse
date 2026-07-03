# frozen_string_literal: true

# Event embeds. `event_id` is the source `original_id` of an event converted by its
# own step (the `events` table). The importer renders that event into the post body
# once it exists. `placeholder` holds the token put in `post.raw`; see
# `Migrations::Placeholder`.
Migrations::Tooling::Schema.table :post_events do
  synthetic!

  add_column :post_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :event_id, :numeric

  index :post_id
end
