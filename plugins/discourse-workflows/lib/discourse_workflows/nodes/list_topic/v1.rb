# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ListTopic
      class V1 < NodeType
        include TopicStatusAction

        STATUS = "visible"
        ENABLED = true
        PERMISSION = :ensure_can_toggle_topic_visibility!
        STATUS_OPTIONS = {
          visibility_reason_id: ::Topic.visibility_reasons[:manually_relisted],
        }.freeze

        description(TopicStatusAction.description(name: "action:list_topic", icon: "eye"))
      end
    end
  end
end
