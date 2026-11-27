# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ArchiveTopic
      class V1 < NodeType
        include TopicStatusAction

        STATUS = "archived"
        ENABLED = true
        PERMISSION = :ensure_can_archive_topic!

        description(
          TopicStatusAction.description(name: "action:archive_topic", icon: "box-archive"),
        )
      end
    end
  end
end
