# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Base class for construct detectors.
          class Base
            # @return [Match, nil]
            def detect(input, pos)
              raise NotImplementedError, "#{self.class} must implement #detect"
            end

            private

            # A username is Unicode alphanumerics, combining marks, `_` and `-` — the
            # characters Discourse allows (see core's `UsernameValidator`). Plain
            # `\w` is ASCII-only, so it would cut `@café` down to `@caf` and leave the
            # rest behind; `\p{Alnum}\p{M}` also covers decomposed forms like
            # `@café`. `\G` anchors the match at `pos`, so we match in place
            # instead of slicing off the tail of the input first.
            WORD_PATTERN = /\G[\p{Alnum}\p{M}_-]*/
            private_constant :WORD_PATTERN

            WORD_BOUNDARY = /[\p{Alnum}\p{M}_]/
            private_constant :WORD_BOUNDARY

            def word_boundary?(input, pos)
              return true if pos.zero?

              !input[pos - 1].match?(WORD_BOUNDARY)
            end

            # Extract a word starting at position. Caller must ensure pos is within
            # bounds (`pos <= input.length`).
            def extract_word(input, pos)
              WORD_PATTERN.match(input, pos)[0]
            end
          end
        end
      end
    end
  end
end
