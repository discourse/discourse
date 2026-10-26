# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnarchiveTopic
      class V1 < NodeType
        include TopicStatusAction

        STATUS = "archived"
        ENABLED = false
        PERMISSION = :ensure_can_archive_topic!

        description(
          TopicStatusAction.description(name: "action:unarchive_topic", icon: "folder-open"),
        )
      end
    end
  end
end
