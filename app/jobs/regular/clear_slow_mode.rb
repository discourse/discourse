# frozen_string_literal: true

module Jobs
  class ClearSlowMode < ::Jobs::Base

    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id] || args[:topic_status_update_id])

      if topic_timer.nil? || topic_timer.execute_at > Time.zone.now
        return
      end

      topic = topic_timer&.topic

      if topic.nil?
        topic_timer.destroy!
        return
      end

      topic.update!(slow_mode_seconds: 0)
      topic_timer.trash!(Discourse.system_user)
    end
  end
end
