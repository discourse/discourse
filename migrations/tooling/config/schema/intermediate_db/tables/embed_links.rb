# frozen_string_literal: true

# Link embeds. An internal link the importer rewrites once the `original_id ->
# discourse_id` maps exist; an external link is just text carried through. `url`
# holds the full source URL and is the fallback whenever the target can't be
# resolved. `text` is a markdown link's link text (nil for a bare URL, which the
# renderer emits bare to keep oneboxes working). `placeholder` holds the token
# spliced into the owner's markdown (a post body today, a user bio etc. later); see
# `Migrations::Placeholder`. `owner_type`/`owner_id` name that owning record.
#
# `target_type` is the kind of Discourse entity the link points at, a `link_target`
# value (`topic`, `post`, `user`, `category`, `tag`, `group` or `badge`); nil for an
# external link. The entity is identified in one of three forms, and only one is set
# per row: by id (`target_id`, the source `original_id`), by name (`target_name`),
# or by coordinates (`target_topic_id` + `target_post_number`). Which form a row
# uses follows from what the URL carries — with a Discourse source:
#
#   * topic     `/t/a-topic/123`, `/t/123`  -> target_id: 123
#   * post      `/p/456`                    -> target_id: 456
#   * post      `/t/a-topic/123/7`          -> target_topic_id: 123, target_post_number: 7
#   * user      `/u/sam`, `/users/sam`      -> target_name: "sam"
#   * category  `/c/cars/tesla/89`          -> target_id: 89
#   * category  `/c/cars/tesla` (legacy)    -> target_name: "cars:tesla"
#   * tag       `/tag/photo`, `/tags/photo` -> target_name: "photo"
#   * group     `/g/moderators`             -> target_name: "moderators"
#   * badge     `/badges/9/first-like`      -> target_id: 9
#
# A category slug path is stored with a `:` separator, matching the hashtag
# resolution maps so the importer reuses them verbatim. Post coordinates mirror
# `embed_quotes`: post numbers are recomputed at import, so the importer resolves
# them to a post rather than preserving them.
# `target_suffix` is everything after the matched route (further path, query string,
# fragment), reattached verbatim when the URL is rebuilt: `/u/sam/summary` yields
# target_name: "sam" plus target_suffix: "/summary", and `/t/a-topic/123?page=2`
# yields target_id: 123 plus target_suffix: "?page=2".
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
