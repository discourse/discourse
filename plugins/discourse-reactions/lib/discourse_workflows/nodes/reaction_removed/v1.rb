# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ReactionRemoved
        class V1 < PostReactionChanged::V2
          description(
            PostReactionChanged::V2.description_for_change(
              "trigger:reaction_removed",
              "removed",
            ).merge(defaults: { icon: "far-face-meh", color: "yellow" }),
          )
        end
      end
    end
  end
end
