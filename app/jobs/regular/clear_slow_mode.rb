# frozen_string_literal: true

module Jobs
  class ClearSlowMode < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      topic.update!(slow_mode_seconds: 0)
      topic_timer.finish!(:completed)

      if topic.saved_change_to_slow_mode_seconds?
        DiscourseEvent.trigger(:topic_slow_mode_cleared, topic, acting_user: Discourse.system_user)
      end
    end
  end
end
