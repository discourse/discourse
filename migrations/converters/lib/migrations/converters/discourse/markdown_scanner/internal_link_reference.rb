# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # A deferred internal link — a URL pointing at another record on the same
        # Discourse (a topic, post, user, category, tag, group or badge). The entity
        # it names is resolved at import (ids and slugs change), so the node carries
        # what the URL revealed and lets the importer finish it.
        #
        # `url` is the full original URL and the importer's fallback. `text` is a
        # markdown link's link text, or nil for a bare URL (which the renderer emits
        # bare, so oneboxes keep working). `target_type` is a symbol naming the kind
        # (`:topic`, `:post`, `:user`, `:category`, `:tag`, `:group`, `:badge`, or
        # `:site`); the {RawExtractor} maps it to the stored enum.
        #
        # For a routed target exactly one addressing form is filled: `target_id` (a
        # source `original_id`), `target_name` (a username, group/tag name, or a
        # `parent:child` category slug path), or `target_topic_id` +
        # `target_post_number` (a post addressed by coordinates). `target_suffix` is
        # whatever trailed the matched route (further path, query string, fragment),
        # reattached verbatim at render.
        #
        # A `:site` target names no record — an absolute internal URL that parses no
        # route (a real page like `/faq`, or junk). None of the addressing fields are
        # filled; `target_suffix` carries the whole path/query/fragment (after any host
        # prefix), and the importer renders the destination base URL plus that suffix.
        InternalLinkReference =
          Data.define(
            :url,
            :text,
            :target_type,
            :target_id,
            :target_name,
            :target_topic_id,
            :target_post_number,
            :target_suffix,
          )
      end
    end
  end
end
