# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred internal link — a URL pointing at another record on the
        # same Discourse. The entity it names is resolved at import (ids and
        # slugs change), so the node carries what the URL revealed.
        #
        # `url` is the full original URL and the importer's fallback. `text` is
        # a markdown link's link text, or nil for a bare URL (which the renderer
        # emits bare, so oneboxes keep working). `target_type` is a symbol
        # naming the kind (`:topic`, `:post`, `:user`, `:category`, `:tag`,
        # `:group`, `:badge`, or `:site`); the {RawExtractor} maps it to the
        # stored enum.
        #
        # For a routed target exactly one addressing form is filled: `target_id`
        # (a source `original_id`), `target_name` (a username, group/tag name,
        # or a `parent:child` category slug path), or `target_topic_id` +
        # `target_post_number`. `target_suffix` is whatever trailed the matched
        # route, reattached verbatim at render.
        #
        # The multi-coordinate tag routes carry a second coordinate in
        # `target_tag_path`: a `:category_tag` link names its category through
        # `target_id`/`target_name` as above, plus the tag as
        # `[none/|all/]<tag-name>`; a `:tag_intersection` link names only tags,
        # `<t1>/<t2>[/…]`. Tag names come from URL path segments, so `/` can't
        # occur inside one.
        #
        # A `:site` target names no record: no addressing field is filled,
        # `target_suffix` carries the whole path/query/fragment, and the
        # importer renders the destination base URL plus that suffix.
        #
        # `url_offset` is the destination's byte offset within the verbatim
        # source snippet, and `label_url_offset` the offset of a self-link label
        # spelling the same destination (nil otherwise); both spans are
        # `url.bytesize` long.
        InternalLinkReference =
          Data.define(
            :url,
            :text,
            :target_type,
            :target_id,
            :target_name,
            :target_topic_id,
            :target_post_number,
            :target_tag_path,
            :target_suffix,
            :url_offset,
            :label_url_offset,
          )
      end
    end
  end
end
