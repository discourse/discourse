# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module DeleteTopic
      class V1 < NodeType
        include TopicDeletion

        DELETED = true

        description(
          TopicDeletion.description(name: "action:delete_topic", icon: "trash-can", color: "red"),
        )

        private

        def change_deletion(exec_ctx, topic, actor)
          exec_ctx.destroy_topic(user: actor, topic:)
        end
      end
    end
  end
end
