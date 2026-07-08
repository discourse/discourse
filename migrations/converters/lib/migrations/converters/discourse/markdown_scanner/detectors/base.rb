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

            private

            # Anchored match at a byte offset: every PATTERN here is `\G`-anchored, so
            # `byteindex` matches AT `pos` or returns nil (no forward drift) — the
            # byte-offset analogue of `PATTERN.match(input, pos)`, but positioned in
            # O(1) no matter how many multibyte characters precede `pos`. The returned
            # MatchData's `byteoffset`s are byte offsets into `input`.
            #
            # `byteindex` returns `0` for a match at the start of input, which is
            # falsy, so the result is nil-checked rather than tested for truthiness.
            def match_at(pattern, input, pos)
              return nil if input.byteindex(pattern, pos).nil?

              Regexp.last_match
            end

            # A username the way core's `UsernameValidator` (and the markdown-it
            # mentions rule) reads it: it starts with a Unicode alphanumeric, mark or
            # `_`; its interior may also hold `.` and `-`; and it ends on an
            # alphanumeric or mark — never on `.`, `-` or `_`. So a sentence's
            # trailing `@bob.` keeps its period out of the name, while `@john.doe`
            # matches whole. Plain `\w` is ASCII-only (it would cut `@café` to `@caf`);
            # `\p{Alnum}\p{M}` also covers decomposed forms like `@café`. `\G` anchors
            # the match at `pos`, so we match in place instead of slicing off the tail
            # of the input first.
            WORD_PATTERN = /\G[\p{Alnum}\p{M}_](?:[\p{Alnum}\p{M}._-]*[\p{Alnum}\p{M}])?/
            private_constant :WORD_PATTERN

            WORD_BOUNDARY = /[\p{Alnum}\p{M}_]/
            private_constant :WORD_BOUNDARY

            # `pos` is a byte offset, so `getbyte(pos - 1)` is always the last byte of
            # the previous character. An ASCII byte (< 0x80) is that whole character,
            # tested directly. A byte >= 0x80 is the trailing byte of a multibyte
            # character, and the boundary test is Unicode-aware (`WORD_BOUNDARY`
            # matches marks and non-ASCII alphanumerics), so we recover the actual
            # character with {#previous_char} and test it.
            def word_boundary?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              if byte < 0x80
                !(ascii_alnum_byte?(byte) || byte == 0x5f) # 0x5f = `_`
              else
                !previous_char(input, pos).match?(WORD_BOUNDARY)
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

            # Caller guarantees `pos > 0`. `!` is ASCII, so a multibyte previous
            # character's trailing byte simply isn't 0x21.
            def bang_before?(input, pos)
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
