# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # Custom emoji shortcodes (`:name:`), deferred only when the name is
          # one of the source's own custom emoji. Standard emoji, a stray
          # `:word:` in prose and clock times all pass through untouched.
          #
          # Whether a shortcode opens where it sits, and what a tone suffix
          # resolves to, is core's business (see {MarkdownScanner}). Core
          # lowercases a shortcode before the custom lookup, so `:MYEMOJI:` is
          # the same emoji as `:myemoji:`.
          class Emoji < Base
            TRIGGERS = [":"].freeze

            # A bare `:` is far too common for the gate's presence check, while
            # the `:name:` shape keeps plain posts skipping all work. Wider than
            # a custom emoji name (which core spells lowercase and ASCII): the
            # raw may spell the name in any case.
            PRESENCE_PATTERN = /:[[:alnum:]_+-]+:/
            private_constant :PRESENCE_PATTERN

            # @param names [Migrations::CompactStringSet] the source's custom
            #   emoji names, already folded.
            def initialize(names:)
              @names = names
            end

            # The folded name set, for the {TierGate}'s candidate probe, which
            # folds the raw itself and so needs the set unmediated.
            attr_reader :names

            def presence_pattern
              PRESENCE_PATTERN
            end

            def tracked_name?(name)
              @names.include?(normalize(name))
            end

            # The node for a confirmed occurrence. The name keeps the author's
            # spelling, which the importer folds when it looks the emoji up.
            def node_for(text)
              EmojiReference.new(name: text.delete_prefix(":").delete_suffix(":"))
            end
          end
        end
      end
    end
  end
end
