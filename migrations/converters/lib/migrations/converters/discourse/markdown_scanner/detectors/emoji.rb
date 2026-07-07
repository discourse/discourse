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
          # or punctuation. We diverge in two small ways: a preceding `:` is not a
          # boundary here (it would be the closing colon of an adjacent shortcode),
          # and the name is restricted to real emoji-name characters rather than
          # "anything up to the next colon".
          class Emoji < Base
            TRIGGER = ":"

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

            def detect(input, pos)
              return nil unless input[pos] == TRIGGER
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
            # other than `:`. An alphanumeric before `:` means it's glued to a word,
            # and a preceding `:` is the closing colon of the token before it — as in
            # a `10:30:45` timestamp — so neither counts.
            def boundary_before?(input, pos)
              return true if pos.zero?

              !input[pos - 1].match?(/[[:alnum:]:]/)
            end
          end
        end
      end
    end
  end
end
