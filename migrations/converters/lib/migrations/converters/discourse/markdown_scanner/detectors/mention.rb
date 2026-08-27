# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Detectors
          # Detects user and group mentions (`@name`). The mention *type* is decided
          # later by the converter's MentionClassifier (it needs the source's groups
          # and `here_mention` setting), so the node just carries the name.
          #
          # Only a mention naming one of the source's mention names (every username,
          # group name, the `here_mention` value and `all`) is deferred; anything
          # else (`@3pm`) stays literal text. The names are required: deferring every
          # `@word` that parses rewrites text that names nobody, and the importer
          # then resolves it against the destination.
          #
          # This mirrors what core actually renders, which is core's markdown-it
          # mentions rule (`discourse-markdown-it/src/features/mentions.js`) as applied
          # by the text-post-process engine
          # (`discourse-markdown-it/src/features/text-post-process.js`). The engine
          # runs the rule only when the character before *and* after the whole `@name`
          # match is whitespace or, per markdown-it's `isPunctChar`, a punctuation or
          # symbol character — see {Boundaries#mention_boundary_before?} and
          # {Boundaries#mention_boundary_after?}, both verified against PrettyText. A mention
          # whose name doesn't resolve to a real user or group renders as an inert
          # `<span class="mention">` in core, never a cooked link, so gating on the
          # source's names keeps extraction in step with what core cooks.
          #
          # The grammar here carries no length cap, unlike core's 60-character
          # name regex: extraction inherits the cap anyway, because an
          # over-long name produces no engine token and nothing certifies.
          class Mention < Base
            TRIGGERS = ["@"].freeze

            # @param names [Migrations::CompactStringSet] the source's mention names,
            #   already normalized. A mention is deferred only if its (normalized)
            #   name is in the set.
            def initialize(names:)
              @names = names
            end

            def detect(input, pos, _byte)
              return nil unless mention_boundary_before?(input, pos)

              name = extract_word(input, pos + 1)
              return nil if name.empty?

              end_pos = pos + 1 + name.bytesize # +1 for the `@` (one byte)
              return nil unless mention_boundary_after?(input, end_pos)
              return nil unless @names.include?(normalize(name))

              Match.new(start_pos: pos, end_pos:, node: Markbridge::AST::Mention.new(name:))
            end
          end
        end
      end
    end
  end
end
