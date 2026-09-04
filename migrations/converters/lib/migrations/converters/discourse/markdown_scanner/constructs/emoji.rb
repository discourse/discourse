# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Custom emoji shortcodes (`:name:`), deferred only when the name is one of
          # the source's own custom emoji. Standard emoji, a stray `:word:` in prose
          # and clock times all pass through untouched. This construct requires its
          # name set — there is nothing to defer without it — and a source with no
          # custom emoji leaves it out entirely, so those posts never pay for the `:`
          # trigger.
          #
          # Whether a shortcode opens where it sits, and what a tone suffix resolves
          # to, is core's business: the {EngineScanner} reads the shortcodes the real
          # parse reported and locates them in the raw by counting. Core lowercases a
          # shortcode before the custom lookup, so `:MYEMOJI:` is the same emoji as
          # `:myemoji:` and counting folds the raw the same way.
          class Emoji < Base
            TRIGGERS = [":"].freeze

            # A bare `:` is far too common for the gate's presence check, while the
            # `:name:` shape keeps plain posts skipping all work. Wider than a custom
            # emoji name (which core spells lowercase and ASCII): the raw may spell
            # the name in any case, and a source's own name may hold anything the
            # importer can look up again.
            PRESENCE_PATTERN = /:[[:alnum:]_+-]+:/
            private_constant :PRESENCE_PATTERN

            # @param names [Migrations::CompactStringSet] the source's custom emoji
            #   names, already folded.
            def initialize(names:)
              @names = names
            end

            # The folded name set, for the {TierGate}'s candidate probe, which
            # folds the raw itself and so needs the set unmediated.
            attr_reader :names

            def presence_pattern
              PRESENCE_PATTERN
            end

            # Whether `name` is one of the source's custom emoji — the engine
            # tier's token filter asks the construct so filter and node share
            # one name set and one folding.
            def tracked_name?(name)
              @names.include?(normalize(name))
            end

            # The node for a confirmed occurrence, from its raw bytes. The name
            # keeps the author's spelling, which the importer folds when it
            # looks the emoji up.
            def node_for(text)
              EmojiReference.new(name: text.delete_prefix(":").delete_suffix(":"))
            end
          end
        end
      end
    end
  end
end
