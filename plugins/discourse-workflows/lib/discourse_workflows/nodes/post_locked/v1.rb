# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostLocked
      class V1 < NodeType
        include PostModerationTrigger

        description(
          PostModerationTrigger.description(
            name: "trigger:post_locked",
            event: :post_locked,
            icon: "lock",
            color: "light-blue",
          ),
        )
      end
    end
  end
end
