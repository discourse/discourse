# frozen_string_literal: true

# `#slug` / `#parent:child` hashtag embeds. A hashtag names a category or a tag
# whose slug/name can change at import (merges, renames), so the converter records
# the reference and the importer rewrites it once the maps exist.
#
# `name` is the hashtag as written, without the leading `#` and without any
# `::tag`/`::category` suffix; it may hold one `:` as the `parent:child` separator.
# `hashtag_type` is a `HashtagType` value (`category` or `tag`), or nil to mean
# "classify at import". The converter sets it only when the source text forced it
# with a `::tag`/`::category` suffix; otherwise the importer decides (categories
# first, then tags) and fills it in. `target_id` holds the source `original_id` of
# the resolved category or tag, nil until the importer resolves the name.
#
# `placeholder` holds the token spliced into the owner's markdown; `owner_type`/
# `owner_id` name that owning record.
Migrations::Tooling::Schema.table :embed_hashtags do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :hashtag_type, :integer, enum: :hashtag_type
  add_column :target_id, :numeric
  add_column :name, :text, required: true

  index :owner_type, :owner_id
end
