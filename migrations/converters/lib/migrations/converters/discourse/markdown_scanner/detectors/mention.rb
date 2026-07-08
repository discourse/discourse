# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects user and group mentions (`@name`). The mention *type* is decided
          # later by the converter's MentionResolver (it needs the source's groups
          # and `here_mention` setting), so the node just carries the name.
          #
          # When the caller supplies the source's mention names (every username,
          # group name, the `here_mention` value and `all`), only a mention naming
          # one of them is deferred; anything else (`@3pm`) stays literal text.
          # Without a name set every `@word` that parses is deferred, so callers with
          # no source metadata keep the old syntactic behavior.
          class Mention < Base
            # @param names [Migrations::SortedStringSet, nil] the source's mention
            #   names, already normalized. When given, a mention is deferred only if
            #   its (normalized) name is in the set. `nil` means no gate.
            def initialize(names: nil)
              @names = names
            end

            def detect(input, pos)
              return nil unless input[pos] == "@"
              return nil unless word_boundary?(input, pos)

              name = extract_word(input, pos + 1)
              return nil if name.empty?
              return nil if @names && !@names.include?(normalize(name))

              Match.new(
                start_pos: pos,
                end_pos: pos + 1 + name.length,
                node: Markbridge::AST::Mention.new(name:),
              )
            end

            private

            # Same normalization the importer applies when it resolves the mention to
            # a user or group, so the gate and the resolution can't disagree.
            def normalize(name)
              Migrations::NameNormalizer.normalize(name)
            end
          end
        end
      end
    end
  end
end
