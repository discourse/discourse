# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        # One class per construct kind, tried in priority order at each
        # trigger character. Each returns a {Match} or nil.
        module Constructs
          # Result of a successful detection: the byte span the construct
          # covers and the AST node describing it.
          Match = Data.define(:start_pos, :end_pos, :node)

          # The part of a construct's contract that is independent of the
          # syntax it parses: the {TierGate}'s presence hook, and the
          # byte-offset matching every grammar here is written for. {Base}
          # adds the inline-syntax contract (`TRIGGERS` and `#detect`) on top
          # of this; a construct that parses a block opener instead — the
          # {Quote} header — mixes in only this much.
          module Detection
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

            # Anchored match at a byte offset: every PATTERN here is `\G`-anchored, so
            # `byteindex` matches at `pos` or not at all — the byte-offset analogue of
            # `PATTERN.match(input, pos)`, but positioned in O(1) no matter how many
            # multibyte characters precede `pos`. The returned MatchData's
            # `byteoffset`s are byte offsets into `input`.
            def match_at(pattern, input, pos)
              input.byteindex(pattern, pos) && Regexp.last_match
            end
          end
        end
      end
    end
  end
end
