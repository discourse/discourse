# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ReactionChanged
        class V1 < PostReactionChanged::V2
          description(
            PostReactionChanged::V2.description_for_change(
              "trigger:reaction_changed",
              "replaced",
            ).merge(defaults: { icon: "far-face-smile", color: "yellow" }),
          )
        end
      end
    end
  end
end
