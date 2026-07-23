# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Base class for construct detectors.
          class Base
            # The characters this detector can match at (each subclass's `TRIGGERS`).
            # The scanner dispatches by character, so a position only runs the
            # detectors that can match there.
            #
            # @return [Array<String>]
            def triggers
              self.class::TRIGGERS
            end

            # `pos` is a byte offset into `input` and `byte` is `input.getbyte(pos)`,
            # already read by the scanner's walk. Dispatch is keyed by byte, so
            # `byte` is always the ordinal of one of {#triggers}.
            #
            # @return [Match, nil]
            def detect(input, pos, byte)
              raise NotImplementedError, "#{self.class} must implement #detect"
            end

            # A regexp the scanner adds to its skip check (see
            # `Scanner::MAYBE_EMBED`) when this detector is wired: a body matching
            # neither that check nor any detector's pattern is returned without
            # being walked. Only a detector whose constructs don't always contain
            # a `MAYBE_EMBED` character needs one; nil (the default) means the
            # built-in check already covers this detector.
            #
            # @return [Regexp, nil]
            def presence_pattern
              nil
            end

            private

            # Same normalization the importer applies when it resolves the name to a
            # user, group, category or tag, so the gate and the resolution can't
            # disagree.
            def normalize(name)
              Migrations::NameNormalizer.normalize(name)
            end

            # Anchored match at a byte offset: every PATTERN here is `\G`-anchored, so
            # `byteindex` matches at `pos` or not at all — the byte-offset analogue of
            # `PATTERN.match(input, pos)`, but positioned in O(1) no matter how many
            # multibyte characters precede `pos`. The returned MatchData's
            # `byteoffset`s are byte offsets into `input`.
            def match_at(pattern, input, pos)
              input.byteindex(pattern, pos) && Regexp.last_match
            end

            # A username the way core's `UsernameValidator` (and the markdown-it
            # mentions rule) reads it: it starts with a Unicode alphanumeric, mark or
            # `_`; its interior may also hold `.` and `-`; and it ends on an
            # alphanumeric or mark — never on `.`, `-` or `_`. So in `@bob.` the
            # trailing `.` is not part of the name, while `@john.doe` matches whole.
            # Plain `\w` is ASCII-only (it would cut `@café` to `@caf`);
            # `\p{Alnum}\p{M}` also covers decomposed forms like `@café`.
            #
            # The source is shared with `InternalLink::WORD`, which reads a `/u/<name>`
            # segment the same way but unanchored.
            WORD_SOURCE = "[\\p{Alnum}\\p{M}_](?:[\\p{Alnum}\\p{M}._-]*[\\p{Alnum}\\p{M}])?"

            # `\G` anchors the match at `pos`, so we match in place instead of slicing
            # off the tail of the input first.
            WORD_PATTERN = /\G#{WORD_SOURCE}/
            private_constant :WORD_PATTERN

            # The boundary markdown-it's text-post-process engine enforces around a
            # whole match: whitespace or, per markdown-it's `isPunctChar`, a Unicode
            # punctuation or symbol character. `\p{Z}` covers the wide spaces (NBSP,
            # ideographic space) markdown-it counts as whitespace that Ruby's `\s`
            # misses. Shared by the detectors whose construct only fires on such a
            # boundary (mentions, hashtags). Verified against PrettyText — this
            # boundary is imposed by the engine, not shown by the rule's own regex.
            PUNCTUATION_OR_SYMBOL = /[\p{P}\p{S}\p{Z}]/
            private_constant :PUNCTUATION_OR_SYMBOL

            # The character set core's emoji rule (`discourse-markdown-it/src/
            # features/emoji.js`) accepts before a shortcode's opening `:`, per
            # markdown-it's `isPunctChar`: a Unicode punctuation or symbol. Unlike
            # {PUNCTUATION_OR_SYMBOL} (the text-post-process boundary shared by
            # mentions and hashtags) this leaves out `\p{Z}`: the emoji rule's
            # `isSpace`/`isPunctChar` both reject the wide spaces (NBSP, ideographic
            # space, category Zs), so a shortcode glued right after one stays
            # literal. Verified against PrettyText.
            EMOJI_PUNCTUATION_OR_SYMBOL = /[\p{P}\p{S}]/
            private_constant :EMOJI_PUNCTUATION_OR_SYMBOL

            # The zero-width space the emoji rule special-cases as a valid character
            # before the opening `:`, alongside whitespace and punctuation. It is
            # category Cf, so neither `isSpace` nor `isPunctChar` covers it.
            ZERO_WIDTH_SPACE = "\u200B"
            private_constant :ZERO_WIDTH_SPACE

            # A record id: at most 18 digits. Ids are stored as SQLite signed 64-bit
            # integers, and a 19-digit run overflows that range (binding the bignum
            # raises). No real record has more than 18 digits anyway — a longer run is
            # a numeric title or junk that names no record, so it stays literal text.
            # Unanchored, so it composes into the route patterns; every use site
            # anchors it or guards it with a lookahead, which makes an overlong run
            # fail entirely instead of matching an 18-digit prefix.
            ID_PATTERN = /\d{1,18}/

            # The characters that terminate a URL body: whitespace, `)` (which closes
            # a markdown link), and the quotes and angle brackets that delimit a bare
            # URL. This is the inner negated set, so `[^#{URL_TERMINATORS}]` is a
            # URL-body character. `UploadUrl::URL` also excludes `/` from it
            # (`[^/#{URL_TERMINATORS}]`) to match a single path segment.
            URL_TERMINATORS = "\\s)\"'<>"

            # A mention (`@name`) opens only when the `@` sits on a boundary: the
            # start of input, whitespace, or a punctuation/symbol character. Verified
            # against PrettyText: the engine's boundary is punctuation-or-space, not
            # "not a word character", so a `_` before the `@` (`a_@name`) opens a
            # mention (core cooks it) while `@` glued to a letter or digit does not.
            #
            # `pos` is a byte offset, so `getbyte(pos - 1)` is the last byte of the
            # previous character. An ASCII byte (< 0x80) is that whole character; a
            # byte >= 0x80 is the trailing byte of a multibyte character, so we recover
            # the actual character with {#previous_char} and test it Unicode-aware.
            def mention_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              # A `\` escapes the `@` into a literal (`\@name`), so it never opens a
              # mention even though `\` is itself punctuation.
              return false if byte == 0x5c # `\`

              if byte < 0x80
                whitespace_byte?(byte) || ascii_punct_or_symbol_byte?(byte)
              else
                PUNCTUATION_OR_SYMBOL.match?(previous_char(input, pos))
              end
            end

            # The forward half of the same boundary: `pos` is the byte right after the
            # name, and the mention opens only when that is the end of input,
            # whitespace, or a punctuation/symbol character. Verified against
            # PrettyText: `@name²` (a `²`, category No, right after the name) is not a
            # boundary, so core leaves it literal. The name match already stops on a
            # non-word character, so this only rejects the few that are neither a
            # boundary nor a word character (numbers like `²`, format characters).
            def mention_boundary_after?(input, pos)
              return true if pos >= input.bytesize

              byte = input.getbyte(pos)
              if byte < 0x80
                whitespace_byte?(byte) || ascii_punct_or_symbol_byte?(byte)
              else
                PUNCTUATION_OR_SYMBOL.match?(char_at(input, pos))
              end
            end

            # A custom-emoji shortcode opens only when its `:` sits on core's emoji
            # boundary (`emoji.js`'s `isValidEmojiPrecedingChar`): the start of
            # input, a tab or space (markdown-it's narrow `isSpace`) or a newline (a
            # line break splits the text into separate tokens before the emoji rule
            # runs, so a shortcode after one opens at the start of its own fragment),
            # a Unicode punctuation or symbol (`isPunctChar` — which includes the
            # closing `:` of an adjacent shortcode, so `:a::b:` defers both), or the
            # zero-width space the rule special-cases. Verified against PrettyText:
            # NBSP and ideographic space (both Zs), a soft hyphen (Cf), and `²`/`½`
            # (No) are none of these, so core leaves a shortcode after one literal.
            #
            # `pos` is a byte offset, so `getbyte(pos - 1)` is the previous
            # character's last byte: an ASCII byte is that whole character, a byte
            # >= 0x80 its trailing byte, recovered with {#previous_char} and tested
            # Unicode-aware.
            def emoji_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              # A `\` escapes the `:` into a literal `:` (core drops the shortcode),
              # so nothing opens after it even though `\` is itself punctuation.
              return false if byte == 0x5c # `\`

              if byte < 0x80
                emoji_space_byte?(byte) || ascii_punct_or_symbol_byte?(byte)
              else
                char = previous_char(input, pos)
                char == ZERO_WIDTH_SPACE || EMOJI_PUNCTUATION_OR_SYMBOL.match?(char)
              end
            end

            # markdown-it's `isSpace` (tab and space) widened by the newline that a
            # line break leaves in front of a shortcode's own text fragment. ASCII-
            # only, so a byte >= 0x80 (part of a multibyte character) is never one of
            # these.
            def emoji_space_byte?(byte)
              byte == 0x20 || byte == 0x09 || byte == 0x0a
            end

            # Matches `/\s/` exactly: space plus `\t\n\v\f\r` (0x09..0x0d). These are
            # pure ASCII, so a byte >= 0x80 (a multibyte character) is never
            # whitespace and falls through to false — no character-wise fallback.
            def whitespace_before?(input, pos)
              return true if pos.zero?

              whitespace_byte?(input.getbyte(pos - 1))
            end

            # `/\s/` as a byte test: space plus `\t\n\v\f\r`. ASCII-only, so a byte
            # >= 0x80 (part of a multibyte character) is never whitespace here.
            def whitespace_byte?(byte)
              byte == 0x20 || (byte >= 0x09 && byte <= 0x0d)
            end

            # Where a bare URL may start: at the line start, after whitespace, or
            # right after a `(`. This is only the cheap first gate — the URL detectors
            # narrow it further once a match tells them whether the URL is relative or
            # absolute, because the boundary alone doesn't separate the two:
            #
            #   * After whitespace or a bare `(` (prose punctuation, `(/t/5)`), only
            #     an absolute URL is rewritten. A schemed or `//host` URL in prose
            #     becomes a link once the post is cooked, so rewriting it keeps a
            #     link a link. A relative path like `/t/5` stays plain text when
            #     cooked, so rewriting it would turn prose into a link that wasn't
            #     there — the detectors leave a relative prose URL alone. (A URL
            #     deeper inside the parens, `(see /t/5)`, is admitted by the
            #     whitespace rule instead.)
            #   * A `](…)` whose bracket wrapped an already-consumed construct — a
            #     `)` sits right before the `]`, as in `[![img](upload)](/t/5)` or an
            #     old lightbox — is an outer link target we want. The URL there is a
            #     real link whether it is relative or absolute, so both are rewritten;
            #     see {#link_target_boundary_before?}.
            #   * A `](…)` after plain bracket text — `[pic](…)`, `![alt](…)`,
            #     `[text](foreign)` — is the image's or link's own target. That
            #     target was already handled at its own trigger (an image src is not
            #     ours; a foreign link is already signalled once), so leave it alone.
            #     Firing here would rewrite an image's source or double-report a
            #     foreign host.
            #
            # All the bytes tested (`(`, `]`, `)`) are ASCII, so a multibyte previous
            # character can never equal them.
            def bare_url_boundary_before?(input, pos)
              return true if whitespace_before?(input, pos)
              return false unless input.getbyte(pos - 1) == 0x28 # 0x28 = `(`

              paren_pos = pos - 1
              return true if paren_pos.zero? || input.getbyte(paren_pos - 1) != 0x5d # 0x5d = `]`

              link_target_boundary_before?(input, pos)
            end

            # The `](…)` outer-link-target boundary: the URL sits right after a `](`
            # and a `)` closes right before the `]`, the `)](` shape. That only
            # happens when the bracket wrapped a construct the walk already consumed —
            # the outer link of a nested image `[![img](upload)](/t/5)` or an old
            # lightbox — so the URL here is a genuine link target. A relative URL is
            # rewritten only at this boundary, where it is a link and not prose.
            #
            # All the bytes tested are ASCII (`(` 0x28, `]` 0x5d, `)` 0x29), so a
            # multibyte previous character can never equal them.
            def link_target_boundary_before?(input, pos)
              return false if pos < 3

              input.getbyte(pos - 1) == 0x28 && input.getbyte(pos - 2) == 0x5d &&
                input.getbyte(pos - 3) == 0x29
            end

            # `!` is ASCII, so a multibyte previous character's trailing byte simply
            # isn't 0x21.
            def bang_before?(input, pos)
              return false if pos.zero?

              input.getbyte(pos - 1) == 0x21 # `!`
            end

            # Every printable ASCII punctuation or symbol character — the four ranges
            # around the digits and letters (`!`..`/`, `:`..`@`, `[`..`` ` ``,
            # `{`..`~`). These are exactly the ASCII characters markdown-it's
            # `isPunctChar` accepts, so they mirror {PUNCTUATION_OR_SYMBOL} on the
            # ASCII fast path. Space (0x20) is whitespace, tested separately.
            def ascii_punct_or_symbol_byte?(byte)
              (byte >= 0x21 && byte <= 0x2f) || (byte >= 0x3a && byte <= 0x40) ||
                (byte >= 0x5b && byte <= 0x60) || (byte >= 0x7b && byte <= 0x7e)
            end

            # The character ending just before `pos`, for the Unicode-aware
            # look-backs. `pos` sits on a character boundary, so when the previous
            # character is multibyte its bytes are the continuation bytes
            # (`10xxxxxx`) right before `pos` plus their lead byte; walk back over
            # them and byteslice that one character.
            def previous_char(input, pos)
              start = pos - 1
              start -= 1 while (input.getbyte(start) & 0xC0) == 0x80
              input.byteslice(start, pos - start)
            end

            # The character starting at the byte offset `pos`, for the Unicode-aware
            # forward look-aheads. `pos` sits on a character boundary, so walk forward
            # over that character's continuation bytes (`10xxxxxx`) and byteslice the
            # one character. Caller must ensure `pos < input.bytesize`.
            def char_at(input, pos)
              stop = pos + 1
              stop += 1 while stop < input.bytesize && (input.getbyte(stop) & 0xC0) == 0x80
              input.byteslice(pos, stop - pos)
            end

            # Extract a word starting at the byte offset, or `""` when nothing there
            # can open one (`WORD_PATTERN` needs a valid leading character). Caller
            # must ensure pos is within bounds (`pos <= input.bytesize`).
            def extract_word(input, pos)
              match_at(WORD_PATTERN, input, pos)&.[](0) || ""
            end
          end
        end
      end
    end
  end
end
