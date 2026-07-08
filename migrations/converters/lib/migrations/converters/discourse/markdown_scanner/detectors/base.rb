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

            # @return [Match, nil]
            def detect(input, pos)
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

            def word_boundary?(input, pos)
              return true if pos.zero?

              !input[pos - 1].match?(WORD_BOUNDARY)
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
