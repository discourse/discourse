# frozen_string_literal: true

module Jobs
  class ClearSlowMode < ::Jobs::Base

    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id])
      return if !topic_timer&.runnable?

      topic = topic_timer.topic
      if topic.blank?
        topic_timer.destroy!
        return
      end

      topic.update!(slow_mode_seconds: 0)
      topic_timer.trash!(Discourse.system_user)
    end
  end
end
