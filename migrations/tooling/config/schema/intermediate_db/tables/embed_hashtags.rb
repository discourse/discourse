# frozen_string_literal: true

# `#slug` / `#parent:child` hashtag embeds. A hashtag names a category or a tag
# whose slug/name can change at import (merges, renames), so the converter records
# the reference and the importer rewrites it once the maps exist.
#
# `name` is the hashtag as written, without the leading `#` and without any
# `::tag`/`::category` suffix; it may hold one `:` as the `parent:child` separator.
# `hashtag_type` is a `HashtagType` value (`category` or `tag`), or nil to mean
# "classify at import". The converter sets it when the source text forced the type
# with a `::tag`/`::category` suffix — or when it sets `target_id`, since an id
# renders only through its type. `target_id` is the source `original_id` of the
# target category or tag, for a converter that identifies the target instead of
# just naming it; a filled id makes the importer skip name resolution. `name` is
# required either way — it's the fallback text when the target can't be mapped at
# import. The importer fills the nil fields (classifying categories first, then
# tags) on its in-memory copy of the row while rendering; it never writes them
# back to this table.
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
