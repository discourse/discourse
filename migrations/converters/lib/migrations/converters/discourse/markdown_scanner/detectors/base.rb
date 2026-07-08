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

            # `char` is `input[pos]`, already read by the scanner's walk — reading
            # it again here would allocate a fresh one-character string per probe.
            # The scanner dispatches by character, so it is always one of {#triggers}.
            #
            # @return [Match, nil]
            def detect(input, pos, char)
              raise NotImplementedError, "#{self.class} must implement #detect"
            end

            private

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

            # The look-backs below run for every probe at a trigger character, so on
            # an all-ASCII body they test the previous BYTE: `input[pos - 1]` would
            # allocate a fresh one-character string each time. `pos` is a CHARACTER
            # index, so the byte shortcut is only valid while the two agree — i.e.
            # while `input.ascii_only?` (an O(1) coderange check). One multibyte
            # character anywhere shifts every later byte offset, so a mixed body
            # takes the character-wise path.
            def word_boundary?(input, pos)
              return true if pos.zero?

              if input.ascii_only?
                byte = input.getbyte(pos - 1)
                !(ascii_alnum_byte?(byte) || byte == 0x5f) # 0x5f = `_`
              else
                !input[pos - 1].match?(WORD_BOUNDARY)
              end
            end

            # Matches `/\s/` exactly: space plus `\t\n\v\f\r` (0x09..0x0d).
            def whitespace_before?(input, pos)
              return true if pos.zero?

              if input.ascii_only?
                byte = input.getbyte(pos - 1)
                byte == 0x20 || (byte >= 0x09 && byte <= 0x0d)
              else
                input[pos - 1].match?(/\s/)
              end
            end

            # Preserves the byte/character distinction the same way (see above).
            def bang_before?(input, pos)
              if input.ascii_only?
                input.getbyte(pos - 1) == 0x21 # `!`
              else
                input[pos - 1] == "!"
              end
            end

            def ascii_alnum_byte?(byte)
              (byte >= 0x30 && byte <= 0x39) || (byte >= 0x41 && byte <= 0x5a) ||
                (byte >= 0x61 && byte <= 0x7a)
            end

            # Extract a word starting at position, or `""` when nothing there can
            # open one (`WORD_PATTERN` needs a valid leading character). Caller must
            # ensure pos is within bounds (`pos <= input.length`).
            def extract_word(input, pos)
              WORD_PATTERN.match(input, pos)&.[](0) || ""
            end
          end
        end
      end
    end
  end
end
