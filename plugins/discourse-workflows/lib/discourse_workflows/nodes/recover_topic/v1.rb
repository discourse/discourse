# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module RecoverTopic
      class V1 < NodeType
        include TopicDeletion

        DELETED = false

        description(
          TopicDeletion.description(
            name: "action:recover_topic",
            icon: "arrow-rotate-right",
            color: "green",
          ),
        )

        private

        def change_deletion(exec_ctx, topic, actor)
          exec_ctx.recover_topic(user: actor, topic:)
        end
      end
    end
  end
end
