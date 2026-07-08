# frozen_string_literal: true

# Link embeds. An internal link the importer rewrites once the `original_id ->
# discourse_id` maps exist; an external link is just text carried through. `url`
# holds the full source URL and is the fallback whenever the target can't be
# resolved. `text` is a markdown link's link text (nil for a bare URL, which the
# renderer emits bare to keep oneboxes working). `placeholder` holds the token
# spliced into the owner's markdown (a post body today, a user bio etc. later); see
# `Migrations::Placeholder`. `owner_type`/`owner_id` name that owning record.
#
# `target_type` is the kind of Discourse entity the link points at (a `link_target`
# value), nil for an external link. The entity is named in one of three forms, and
# only one is set per row:
#   * by id (`target_id`) — the source `original_id`, for a topic, `/p/` post,
#     category with a trailing id, or badge.
#   * by name (`target_name`) — a username, group name, tag name, or a category
#     slug path stored `parent:child` (colon separator, matching the hashtag
#     resolution maps so the importer reuses them verbatim). Used when a URL carries
#     a name but no id.
#   * by coordinates (`target_topic_id` + `target_post_number`) — a post addressed
#     as `/t/slug/<topic_id>/<post_number>`, mirroring `embed_quotes`. Post numbers
#     are recomputed at import, so the importer resolves the coordinates rather than
#     preserving them.
# `target_suffix` is everything after the matched route (further path, query string,
# fragment), reattached verbatim when the URL is rebuilt.
Migrations::Tooling::Schema.table :embed_links do
  synthetic!

  add_column :owner_type, :integer, required: true, enum: :embed_owner
  add_column :owner_id, :numeric, required: true
  add_column :placeholder, :text, required: true
  add_column :url, :text
  add_column :text, :text
  add_column :target_type, :integer, enum: :link_target
  add_column :target_id, :numeric
  add_column :target_name, :text
  add_column :target_topic_id, :numeric
  add_column :target_post_number, :integer
  add_column :target_suffix, :text

  index :owner_type, :owner_id
end
