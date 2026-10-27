# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostUnliked
      class V1 < PostLikeChanged::V2
        description(
          PostLikeChanged::V2.description_for_change("unliked").merge(
            defaults: {
              icon: "far-heart",
              color: "red",
            },
          ),
        )

        def output
          super.except(:change)
        end
      end
    end
  end
end
