# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostUnhidden
      class V1 < NodeType
        include PostHidingTrigger

        description(
          PostHidingTrigger.description(
            name: "trigger:post_unhidden",
            event: :post_unhidden,
            icon: "eye",
            color: "green",
          ),
        )
      end
    end
  end
end
