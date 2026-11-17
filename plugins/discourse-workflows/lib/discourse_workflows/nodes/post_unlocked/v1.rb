# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module PostUnlocked
      class V1 < NodeType
        include PostModerationTrigger

        description(
          PostModerationTrigger.description(
            name: "trigger:post_unlocked",
            event: :post_unlocked,
            icon: "unlock",
            color: "light-blue",
          ),
        )
      end
    end
  end
end
