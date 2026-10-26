# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReopenTopic
      class V1 < NodeType
        include TopicStatusAction

        STATUS = "closed"
        ENABLED = false
        PERMISSION = :ensure_can_close_topic!

        description(TopicStatusAction.description(name: "action:reopen_topic", icon: "unlock"))
      end
    end
  end
end
