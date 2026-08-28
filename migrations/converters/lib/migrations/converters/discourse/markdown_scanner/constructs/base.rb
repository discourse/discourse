# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Base class for the construct classes. The boundary look-arounds
          # they share live in {Boundaries}; the constants here are the
          # shared pattern building blocks.
          class Base
            include Boundaries

            # The characters this construct can match at (each subclass's `TRIGGERS`).
            # The scanner dispatches by character, so a position only runs the
            # constructs that can match there.
            #
            # @return [Array<String>]
            def triggers
              self.class::TRIGGERS
            end

            # `pos` is a byte offset into `input` and `byte` is `input.getbyte(pos)`,
            # already read by the caller. Dispatch is keyed by byte, so `byte`
            # is always the ordinal of one of {#triggers}.
            #
            # @return [Match, nil]
            def detect(input, pos, byte)
              raise NotImplementedError, "#{self.class} must implement #detect"
            end

            # A regexp the {TierGate} adds to its presence check when this
            # class is wired: a body matching neither the gate's built-in
            # check nor any class's pattern is returned without any work.
            # Only a class whose matches don't always contain one of the
            # gate's base presence characters needs one; nil (the default)
            # means the built-in check already covers this class.
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
            # The source is shared with `InternalLink::RouteParser::WORD`, which
            # reads a `/u/<name>` segment the same way but unanchored.
            WORD_SOURCE = "[\\p{Alnum}\\p{M}_](?:[\\p{Alnum}\\p{M}._-]*[\\p{Alnum}\\p{M}])?"

            # `\G` anchors the match at `pos`, so we match in place instead of slicing
            # off the tail of the input first.
            WORD_PATTERN = /\G#{WORD_SOURCE}/
            private_constant :WORD_PATTERN

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

            # Linkify takes a few trailing bytes into a bare URL's href that no
            # URL grammar accepts: a stray `-` or `#`, sentence punctuation, a
            # non-ASCII character glued to the URL. Such a tail is short — one
            # or two characters, a few bytes. A construct match may leave at
            # most this many wordless bytes of a confirmed URL occurrence
            # uncovered; a longer tail means the match stopped inside the URL
            # proper, and replacing a prefix would leave the rest behind as
            # literal text.
            MAX_SWALLOWED_TAIL_BYTES = 16

            # An ASCII word byte, for {swallowed_tail?}.
            TRAILING_WORD = /[0-9A-Za-z_]/
            private_constant :TRAILING_WORD

            # Whether the bytes a match leaves uncovered are such a linkify
            # tail: within the cap and without a word byte. A word byte means
            # the value's URL runs past what the grammar takes (a longer
            # basename or query), not linkify junk.
            def self.swallowed_tail?(tail)
              tail.bytesize <= MAX_SWALLOWED_TAIL_BYTES && !tail.match?(TRAILING_WORD)
            end

            # Link text, with the one level of balanced brackets CommonMark allows
            # (`[see [1]](/t/5)` links with text `see [1]`). The nested bracket
            # must not itself open a link or image — the `(?!\()` — so the `[` of a
            # nested image `[![…](…)](…)` never matches at the outer bracket, which
            # would consume the inner construct without recording it (see `UploadUrl::LINK`).
            # Failing there matches core too: links don't nest, so the inner
            # `[…](…)` wins and the outer bracket stays literal.
            #
            # Every quantifier is capped (CommonMark's own label limit is 999
            # characters) and the whole run is atomic: nested unbounded stars made
            # a bracket-dense body without a closing `](` backtrack across every
            # bracket split, quadratically. On this grammar the greedy reading is
            # the only useful one — the run ends at the first `](` either way — so
            # atomicity changes cost, not matches.
            LINK_TEXT = /(?>[^\[\]]{0,999}(?:\[[^\[\]]{0,999}\](?!\()[^\[\]]{0,999}){0,32})/

            # The padding CommonMark allows inside a link's parentheses. The
            # destination and the title may sit on separate lines, but not across a
            # blank one, so at most one newline.
            LINK_GAP = /[^\S\n]*\n?[^\S\n]*/

            # A link title, which core turns into the anchor's `title` attribute:
            # `[text](url "title")`. Kept to a single line — a title spanning lines is
            # rare, and not matching one leaves the link undetected rather than
            # wrongly detected.
            LINK_TITLE = /(?:"[^"\n]*"|'[^'\n]*'|\([^()\n]*\))/

            # Everything a markdown link allows after its destination: an optional
            # title, padding, and the closing paren. Shared so every construct that
            # reads `[text](url)` accepts the same shapes — a link carrying a title
            # is still a link, and one that doesn't match here is never rewritten.
            LINK_TAIL = /(?:#{LINK_GAP}#{LINK_TITLE})?#{LINK_GAP}\)/

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
