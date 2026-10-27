# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ClearTopicTimer
      class V1 < NodeType
        include TopicTimerAction

        description(
          TopicTimerAction.description(
            name: "action:clear_topic_timer",
            properties: {
            },
            timer_schema: Schema::NULLABLE_TOPIC_TIMER,
            changed_description: "False when the topic had no timer of this type",
          ),
        )

        private

        def change_timer(_exec_ctx, topic, actor, type_id, _item_index)
          timer = topic.topic_timers.find_by(status_type: type_id)
          [timer, timer&.finish!(:cancelled, by_user: actor) || false]
        end
      end
    end
  end
end
