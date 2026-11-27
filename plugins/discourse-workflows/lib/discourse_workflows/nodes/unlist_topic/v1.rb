# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module UnlistTopic
      class V1 < NodeType
        include TopicStatusAction

        STATUS = "visible"
        ENABLED = false
        PERMISSION = :ensure_can_toggle_topic_visibility!
        STATUS_OPTIONS = {
          visibility_reason_id: ::Topic.visibility_reasons[:manually_unlisted],
        }.freeze

        description(
          TopicStatusAction.description(name: "action:unlist_topic", icon: "far-eye-slash"),
        )
      end
    end
  end
end
