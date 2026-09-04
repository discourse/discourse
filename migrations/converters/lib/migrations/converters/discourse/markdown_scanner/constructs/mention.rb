# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # User and group mentions (`@name`). The mention *type* is decided later by
          # the converter's MentionClassifier (it needs the source's groups and
          # `here_mention` setting), so the node just carries the name.
          #
          # Only a mention naming one of the source's mention names (every username,
          # group name, the `here_mention` value and `all`) is deferred; anything
          # else (`@3pm`) stays literal text. The names are required: deferring every
          # `@word` that parses rewrites text that names nobody, and the importer
          # then resolves it against the destination. A mention whose name resolves
          # to no user or group renders as an inert `<span class="mention">` in core,
          # never a cooked link, so gating on the source's names keeps extraction in
          # step with what core cooks.
          #
          # Where a mention actually opens is core's business, not this class's: the
          # {EngineScanner} reads the mentions the real parse reported and locates
          # them in the raw by counting, so no boundary rule is mirrored here (the
          # ones that were had gaps — a `\@name` escape, for one, which core cooks
          # and a grammar-based reading refused).
          class Mention < Base
            TRIGGERS = ["@"].freeze

            # @param names [Migrations::CompactStringSet] the source's mention names,
            #   already folded. A mention is deferred only if its folded name is in
            #   the set.
            def initialize(names:)
              @names = names
            end

            # The folded name set, for the {TierGate}'s candidate probe, which
            # folds the raw itself and so needs the set unmediated.
            attr_reader :names

            # Whether `name` names someone on the source — the engine tier's
            # token filter asks the construct so filter and node share one
            # name set and one folding.
            def tracked_name?(name)
              @names.include?(normalize(name))
            end

            # The node for a confirmed occurrence, from its raw bytes: the name
            # keeps the author's own spelling, which is what the importer stores
            # and falls back to when it can remap nothing.
            def node_for(text)
              Markbridge::AST::Mention.new(name: text.delete_prefix("@"))
            end
          end
        end
      end
    end
  end
end
