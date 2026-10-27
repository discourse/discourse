# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLiked
      class V1 < PostLikeChanged::V2
        description(PostLikeChanged::V2.description_for_change("liked"))

        def output
          super.except(:change)
        end
      end
    end
  end
end
