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
          # `channel #general`) stays literal text. Without a name set, every hashtag
          # that parses is deferred (purely syntactic), for callers with no source
          # metadata.
          #
          # This mirrors what core actually renders, which is core's markdown-it
          # hashtag rule (`discourse-markdown-it/src/features/hashtag-autocomplete.js`)
          # as applied by the text-post-process engine
          # (`discourse-markdown-it/src/features/text-post-process.js`). The engine
          # only runs the rule when the character before and after the whole match is
          # whitespace or, per markdown-it's `isPunctChar`, a Unicode punctuation or
          # symbol character. So we mirror both:
          #
          #   * The `#` must sit on a boundary — start of input, whitespace, or a
          #     punctuation/symbol character. `/` is the one punctuation core still
          #     refuses (the rule's own `(?<!\/)` keeps a URL fragment like `/#section`
          #     out), and `\` is refused too because a `\#` is an escaped `#`. A letter
          #     or digit before the `#` rejects, so a mid-word `word#tag` stays literal.
          #   * The name is our own charset (Unicode alphanumerics, marks, `_`, `-`,
          #     interior `.`) with at most one `:` separating a `parent:child` category
          #     slug. Core allows any number of `:` in a name; we keep the single-`:`
          #     rule, which is why an unknown `#name::channel` chat hashtag stays
          #     literal instead of extracting a truncated `#name`.
          #
          # A hashtag whose name doesn't resolve to a real category or tag renders as
          # inert `hashtag-raw` text in core, never a cooked link, so gating on the
          # source's names (see `@names`) keeps extraction in step with what core cooks.
          class Hashtag < Base
            TRIGGERS = ["#"].freeze

            # One `#slug`, or one half of a `#parent:child` path: a lead of a Unicode
            # alphanumeric, mark, `_` or `-`; an interior that may also hold `.`; and a
            # tail that is never a `.`. So `#v2.0` matches the whole `v2.0`, while a
            # sentence-ending `#general.` keeps the `.` outside the name.
            SEGMENT = "[\\p{Alnum}\\p{M}_-](?:[\\p{Alnum}\\p{M}._-]*[\\p{Alnum}\\p{M}_-])?"
            private_constant :SEGMENT

            # What core's matcher would append to the name. When one of these follows
            # our match, core read a longer — and so different — name than we did and
            # cooked nothing, so we must not extract. It is wider than our own name
            # charset on purpose: core's coarse `Ⰰ-퟿` range swallows CJK
            # spaces and punctuation (e.g. the ideographic space `　`) that our
            # `\p{Alnum}` charset stops at, and a hashtag butted against one of those
            # is not a bare name to core either. An interior `.` (a `.` before another
            # such character) counts the same, so a match takes a whole dotted name or
            # none of it.
            CONTINUATION = "[\\p{Alnum}\\p{M}_\\u00C0-\\u1FFF\\u2C00-\\uD7FF-]"
            private_constant :CONTINUATION

            # `#` + name, an optional `parent:child` (a single `:`), an optional
            # `::tag`/`::category` suffix (case-insensitive), and a trailing guard. The
            # guard refuses a following name character, and also a left-over `::` — an
            # unknown chat-style `#name::channel` suffix, which core leaves as inert
            # text, stays literal rather than matching a truncated `#name`. A lone
            # trailing `:` is left admitted, because core still cooks a dangling
            # `#name:`.
            PATTERN =
              /\G#(?<name>#{SEGMENT}(?::#{SEGMENT})?)(?:::(?<type>tag|category))?(?!#{CONTINUATION}|\.#{CONTINUATION}|::)/i
            private_constant :PATTERN

            # @param names [Migrations::SortedStringSet, nil] the source's category
            #   slug paths and tag names, already normalized. When given, a hashtag is
            #   deferred only if its (normalized) name is in the set. `nil` means no
            #   gate.
            def initialize(names: nil)
              @names = names
            end

            def detect(input, pos, _byte)
              return nil unless boundary_before?(input, pos)

              match = match_at(PATTERN, input, pos)
              return nil unless match

              name = match[:name]
              return nil if @names && !@names.include?(normalize(name))

              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: HashtagReference.new(name:, forced_type: match[:type]&.downcase&.to_sym),
              )
            end

            private

            # A hashtag opens a token only on a boundary: the `#` must start the input,
            # or follow whitespace or a punctuation/symbol character. A leading letter
            # or digit rejects, which drops a mid-word `word#tag`, and a markdown
            # heading's `#` is followed by a space so it never matches a name anyway.
            def boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              if byte < 0x80
                whitespace_byte?(byte) || boundary_punctuation_byte?(byte)
              else
                # A byte >= 0x80 is the tail of a multibyte character; recover the
                # whole character to test it, since the boundary is Unicode-aware.
                PUNCTUATION_OR_SYMBOL.match?(previous_char(input, pos))
              end
            end

            # The ASCII characters that open a hashtag when they sit right before the
            # `#`: every printable ASCII punctuation or symbol character, minus `/` —
            # core's rule refuses a `/`-preceded `#` (a URL fragment) — and `\`, which
            # escapes the `#` into literal text. The gaps between the ranges are the
            # digits and letters, which never open a hashtag.
            def boundary_punctuation_byte?(byte)
              return false if byte == 0x2f || byte == 0x5c # `/`, `\`

              (byte >= 0x21 && byte <= 0x2f) || (byte >= 0x3a && byte <= 0x40) ||
                (byte >= 0x5b && byte <= 0x60) || (byte >= 0x7b && byte <= 0x7e)
            end
          end
        end
      end
    end
  end
end
