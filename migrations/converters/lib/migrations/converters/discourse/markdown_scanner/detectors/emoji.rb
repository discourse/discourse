# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects a custom emoji shortcode (`:name:`) and defers it only when the
          # name is one of the source's own custom emoji. Standard emoji, a stray
          # `:word:` in prose, and clock times all pass through untouched. This
          # detector requires its name set (there's nothing to defer without it).
          #
          # This follows core's emoji rule (`discourse-markdown-it/src/features/
          # emoji.js`): the `:` must sit on a boundary — start of input, whitespace,
          # or punctuation, which includes the closing colon of an adjacent
          # shortcode (`:smile::wink:`). We diverge in one small way: the name is
          # restricted to real emoji-name characters rather than "anything up to
          # the next colon".
          class Emoji < Base
            TRIGGERS = [":"].freeze

            # Emoji names are lowercase; `_`, `+` and `-` appear in a few (`:+1:`,
            # `:-1:`, `:t-rex:`).
            NAME = /[a-z0-9_+-]+/
            private_constant :NAME

            # The lookahead rejects a toned shortcode (`:name:t4:`): core resolves a
            # tone suffix to the toned standard emoji even when a custom emoji has
            # the same name (the custom lookup runs on the tone-inclusive code and
            # never matches), so a toned shortcode can't mean the source's custom
            # emoji and must stay literal. Without the closing colon (`:name:t4`)
            # there is no tone and the shortcode is the custom emoji as usual.
            PATTERN = /\G:(?<name>#{NAME}):(?!t[2-6]:)/
            private_constant :PATTERN

            # A bare `:` is far too common for the scanner's skip check, but the
            # `:name:` shape is selective enough to keep plain posts skipping the
            # walk (see {Base#presence_pattern}).
            PRESENCE_PATTERN = /:#{NAME}:/
            private_constant :PRESENCE_PATTERN

            # @param names [Enumerable<String>] the source's custom emoji names.
            def initialize(names:)
              @names = names.to_set
            end

            def presence_pattern
              PRESENCE_PATTERN
            end

            def detect(input, pos, _byte)
              return nil unless boundary_before?(input, pos)

              match = match_at(PATTERN, input, pos)
              return nil unless match

              name = match[:name]
              return nil if @names.exclude?(name)

              Match.new(
                start_pos: pos,
                end_pos: match.byteoffset(0).last,
                node: EmojiReference.new(name:),
              )
            end

            private

            # A shortcode opens on a boundary: the start, whitespace, or punctuation
            # — including the closing colon of an adjacent shortcode, so chains like
            # `:smile::wink:` defer every shortcode. Only an alphanumeric before the `:`
            # disqualifies it (glued to a word, or the inside of a `10:30:45`
            # timestamp); anything that slips past still has to name a source custom
            # emoji to be deferred.
            def boundary_before?(input, pos)
              return true if pos.zero?

              byte = input.getbyte(pos - 1)
              return !ascii_alnum_byte?(byte) if byte < 0x80

              # The previous character is multibyte, and `[[:alnum:]]` is
              # Unicode-aware, so `é` glues a shortcode to a word the same way `e`
              # does — test the actual character.
              !previous_char(input, pos).match?(/[[:alnum:]]/)
            end
          end
        end
      end
    end
  end
end
