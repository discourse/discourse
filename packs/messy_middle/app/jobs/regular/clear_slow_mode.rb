# frozen_string_literal: true

module Jobs
  class ClearSlowMode < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      topic.update!(slow_mode_seconds: 0)
      topic_timer.trash!(Discourse.system_user)
    end
  end
end
