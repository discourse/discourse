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

            WORD_CHAR = /[\p{Alnum}\p{M}_]/
            private_constant :WORD_CHAR

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

            # `pos` is a byte offset, so `getbyte(pos - 1)` is always the last byte of
            # the previous character. An ASCII byte (< 0x80) is that whole character,
            # tested directly. A byte >= 0x80 is the trailing byte of a multibyte
            # character, and the boundary test is Unicode-aware (`WORD_CHAR`
            # matches marks and non-ASCII alphanumerics), so we recover the actual
            # character with {#previous_char} and test it.
            def word_boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              if byte < 0x80
                !(ascii_alnum_byte?(byte) || byte == 0x5f) # 0x5f = `_`
              else
                !previous_char(input, pos).match?(WORD_CHAR)
              end
            end

            # Matches `/\s/` exactly: space plus `\t\n\v\f\r` (0x09..0x0d). These are
            # pure ASCII, so a byte >= 0x80 (a multibyte character) is never
            # whitespace and falls through to false — no character-wise fallback.
            def whitespace_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              byte == 0x20 || (byte >= 0x09 && byte <= 0x0d)
            end

            # Where a bare URL may start: at the line start, after whitespace, or
            # inside a `(…)` group. The paren case lets the two URL detectors rewrite a
            # URL the walk reaches only because the surrounding `[…]` bracket wasn't
            # consumed as a link — but only the right kind of `(…)`:
            #
            #   * A bare paren group — `(` not preceded by `]` — is prose
            #     punctuation with the URL right after the paren, `(/t/5)`;
            #     rewrite it. (A URL deeper inside the parens, `(see /t/5)`,
            #     is admitted by the whitespace rule instead.)
            #   * A `](…)` whose bracket wrapped an already-consumed construct — a `)`
            #     sits right before the `]`, as in `[![img](upload)](/t/5)` or an old
            #     lightbox — is an outer link target we want; rewrite it.
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

              # A `](` target: only accept it when a `)` closes right before the `]`.
              paren_pos >= 2 && input.getbyte(paren_pos - 2) == 0x29 # 0x29 = `)`
            end

            # `!` is ASCII, so a multibyte previous character's trailing byte simply
            # isn't 0x21.
            def bang_before?(input, pos)
              return false if pos.zero?

              input.getbyte(pos - 1) == 0x21 # `!`
            end

            def ascii_alnum_byte?(byte)
              (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a) ||
                (byte >= 0x61 && byte <= 0x7a)
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
