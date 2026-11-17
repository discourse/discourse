# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module CloseTopic
      class V1 < NodeType
        include TopicStatusAction

        STATUS = "closed"
        ENABLED = true
        PERMISSION = :ensure_can_close_topic!

        description(TopicStatusAction.description(name: "action:close_topic", icon: "lock"))
      end
    end
  end
end
