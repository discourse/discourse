# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects a Discourse hashtag (`#slug`, `#parent:child`, or a forced
          # `#name::tag` / `#name::category`). The category or tag it names is
          # resolved at import (its slug/name can change), so the node just carries
          # the name and any forced type.
          #
          # When the caller supplies the source's category and tag names, only a
          # hashtag whose name is one of them is deferred; anything else (`PR #123`,
          # `channel #general`) stays literal text. Without a name set the detector
          # defers every hashtag that parses, so callers with no source metadata
          # keep the old syntactic behavior.
          #
          # Compared with core's markdown-it hashtag rule
          # (`discourse-markdown-it/src/features/hashtag-autocomplete.js`) this is
          # deliberately stricter, to keep raw extraction from firing on text that
          # only looks like a hashtag:
          #
          #   * The `#` must sit on a boundary — start of input, whitespace or `(`.
          #     Core only refuses a `#` preceded by `/` (a URL fragment), so it would
          #     also match a mid-word `word#tag`. That's too eager for source we're
          #     rewriting blind, so we require the boundary.
          #   * The name is slug characters only (unicode alphanumerics, `_`, `-`)
          #     with at most one `:` separating a `parent:child` category slug. Core
          #     additionally allows interior `.`; we don't, so a trailing sentence
          #     `.` never gets swallowed and slugs (which Discourse generates without
          #     dots) still match.
          class Hashtag < Base
            TRIGGERS = ["#"].freeze

            # `#` + name, an optional `::tag`/`::category` suffix (case-insensitive),
            # and a trailing guard: the match must not be followed by another name
            # character or `:`, so `#foo::channel` (an unknown, chat-style suffix) is
            # left as literal text instead of matching a truncated `#foo`.
            PATTERN =
              /\G\#(?<name>[\p{Alnum}\p{M}_-]+(?::[\p{Alnum}\p{M}_-]+)?)(?:::(?<type>tag|category))?(?![\p{Alnum}\p{M}_:-])/i
            private_constant :PATTERN

            # @param names [Migrations::SortedStringSet, nil] the source's category
            #   slug paths and tag names, already normalized. When given, a hashtag is
            #   deferred only if its (normalized) name is in the set. `nil` means no
            #   gate.
            def initialize(names: nil)
              @names = names
            end

            def detect(input, pos, _char)
              return nil unless boundary_before?(input, pos)

              match = PATTERN.match(input, pos)
              return nil unless match

              name = match[:name]
              return nil if @names && !@names.include?(normalize(name))

              Match.new(
                start_pos: pos,
                end_pos: pos + match[0].length,
                node: HashtagReference.new(name:, forced_type: match[:type]&.downcase&.to_sym),
              )
            end

            private

            # Same normalization the importer applies when it resolves the name to a
            # category or tag, so the gate and the resolution can't disagree.
            def normalize(name)
              Migrations::NameNormalizer.normalize(name)
            end

            # A hashtag starts a new token: the `#` must open the input, or follow
            # whitespace or an opening paren. This drops markdown headings (`# x`,
            # whose `#` is followed by a space anyway), a URL fragment's `/#…`, and a
            # mid-word `#`.
            def boundary_before?(input, pos)
              return true if pos.zero?

              input.getbyte(pos - 1) == 0x28 || whitespace_before?(input, pos) # 0x28 = `(`
            end
          end
        end
      end
    end
  end
end
