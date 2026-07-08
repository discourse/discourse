# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects a custom emoji shortcode (`:name:`) and defers it only when the
          # name is one of the source's own custom emoji. Standard emoji, a stray
          # `:word:` in prose, and clock times all pass through untouched, so this is
          # the one detector configured with state: the set of custom emoji names.
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

            PATTERN = /\G:(?<name>#{NAME}):/
            private_constant :PATTERN

            # Presence gate the scanner ORs into its fast path: a bare `:` is far too
            # common to gate on, but the `:name:` shape is selective enough to keep
            # plain posts skipping the walk.
            GATE = /:#{NAME}:/

            # @param names [Enumerable<String>] the source's custom emoji names.
            def initialize(names:)
              @names = names.to_set
            end

            def detect(input, pos, _char)
              return nil unless boundary_before?(input, pos)

              match = PATTERN.match(input, pos)
              return nil unless match

              name = match[:name]
              return nil if @names.exclude?(name)

              Match.new(
                start_pos: pos,
                end_pos: pos + match[0].length,
                node: EmojiReference.new(name:),
              )
            end

            private

            # A shortcode opens on a boundary: the start, whitespace, or punctuation
            # — including the closing colon of an adjacent shortcode, so chains like
            # `:smile::wink:` defer every link. Only an alphanumeric before the `:`
            # disqualifies it (glued to a word, or the inside of a `10:30:45`
            # timestamp); anything that slips past still has to name a source custom
            # emoji to be deferred.
            def boundary_before?(input, pos)
              return true if pos.zero?
              return !ascii_alnum_byte?(input.getbyte(pos - 1)) if input.ascii_only?

              # `[[:alnum:]]` is Unicode-aware, so `é` glues a shortcode to a word
              # the same way `e` does.
              !input[pos - 1].match?(/[[:alnum:]]/)
            end
          end
        end
      end
    end
  end
end
