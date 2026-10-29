# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module TopicDeleted
      class V1 < NodeType
        include TopicDeletionTrigger

        description(
          TopicDeletionTrigger.description(
            name: "trigger:topic_deleted",
            event: :topic_trashed,
            icon: "trash-can",
            color: "deep-orange",
          ),
        )
      end
    end
  end
end
