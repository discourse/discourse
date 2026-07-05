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
          class Mention < Base
            def detect(input, pos)
              return nil unless input[pos] == "@"
              return nil unless word_boundary?(input, pos)

              name = extract_word(input, pos + 1)
              return nil if name.empty?

              Match.new(
                start_pos: pos,
                end_pos: pos + 1 + name.length,
                node: Markbridge::AST::Mention.new(name:),
              )
            end
          end
        end
      end
    end
  end
end
