# frozen_string_literal: true

# Custom emoji embeds (`:name:`). Only the source's custom emoji become embeds;
# standard `:smile:` shortcodes stay plain text. A custom emoji is keyed by name,
# and the name is exactly what a conflict renames at import, so there's nothing to
# resolve ahead of time — `name` is the source shortcode (without the surrounding
# colons) and the importer rewrites it through the emoji-name map.
#
# `placeholder` holds the token spliced into the owner's markdown; `owner_type`/
# `owner_id` name that owning record.
Migrations::Tooling::Schema.table :embed_emojis do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :name, :text, required: true

  index :owner_type, :owner_id
end
