# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Discourse hashtags (`#slug`, `#parent:child`, or a forced `#name::tag` /
          # `#name::category`). The category or tag a hashtag names is resolved at
          # import (its slug or name can change), so the node just carries the name
          # and any forced type.
          #
          # Only a hashtag naming one of the source's categories or tags is
          # deferred; anything else (`PR #123`, `channel #general`) stays literal
          # text. The names are required: deferring every hashtag that parses
          # rewrites text that names nothing. A hashtag whose name resolves to no
          # real category or tag renders as inert `hashtag-raw` text in core, never a
          # cooked link, so gating on the source's names keeps extraction in step
          # with what core cooks.
          #
          # Which `#word` core reads as a hashtag, and how far the slug reaches, is
          # left to core: the {EngineScanner} takes the slugs from the real parse and
          # locates them in the raw by counting.
          class Hashtag < Base
            TRIGGERS = ["#"].freeze

            # The type a `::category` / `::tag` suffix forces, matched
            # case-insensitively because core's own matcher is.
            FORCED_TYPE = /::(?<type>category|tag)\z/i
            private_constant :FORCED_TYPE

            # @param names [Migrations::CompactStringSet] the source's category slug
            #   paths and tag names, already folded. A hashtag is deferred only if
            #   its folded name is in the set.
            def initialize(names:)
              @names = names
            end

            # The folded name set, for the {TierGate}'s candidate probe, which
            # folds the raw itself and so needs the set unmediated.
            attr_reader :names

            # Whether `name` is a source category slug path or tag name — the
            # engine tier's token filter asks the construct so filter and node
            # share one name set and one folding.
            def tracked_name?(name)
              @names.include?(normalize(name))
            end

            # The node for a confirmed occurrence, from its raw bytes. The name
            # keeps the author's spelling; a forced-type suffix is read off the
            # raw too, because core reports its slug already lowercased.
            def node_for(text)
              ref = text.delete_prefix("#")
              match = FORCED_TYPE.match(ref)
              return HashtagReference.new(name: ref, forced_type: nil) if match.nil?

              HashtagReference.new(
                name: ref[0...match.begin(0)],
                forced_type: match[:type].downcase.to_sym,
              )
            end
          end
        end
      end
    end
  end
end
