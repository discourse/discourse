# frozen_string_literal: true

require "markbridge"

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          # User and group mentions (`@name`). The mention *type* is decided
          # later by the converter's MentionClassifier (it needs the source's
          # groups and `here_mention` setting), so the node just carries the
          # name.
          #
          # Only a mention naming one of the source's mention names (every
          # username, group name, the `here_mention` value and `all`) is
          # deferred; `@3pm` stays literal text. A mention resolving to no user
          # or group renders as an inert `<span class="mention">` in core, never
          # a cooked link, so gating on the source's names keeps extraction in
          # step with what core cooks.
          #
          # Where a mention actually opens is core's business: this class
          # mirrors no boundary rule at all (see {MarkdownScanner}).
          class Mention < Base
            TRIGGERS = ["@"].freeze

            # @param names [Migrations::CompactStringSet] the source's mention
            #   names, already folded. A mention is deferred only if its folded
            #   name is in the set.
            def initialize(names:)
              @names = names
            end

            # The folded name set, for the {TierGate}'s candidate probe, which
            # folds the raw itself and so needs the set unmediated.
            attr_reader :names

            def tracked_name?(name)
              @names.include?(normalize(name))
            end

            # The node for a confirmed occurrence. The name keeps the author's
            # own spelling, which is what the importer stores and falls back to
            # when it can remap nothing.
            def node_for(text)
              Markbridge::AST::Mention.new(name: text.delete_prefix("@"))
            end
          end
        end
      end
    end
  end
end
