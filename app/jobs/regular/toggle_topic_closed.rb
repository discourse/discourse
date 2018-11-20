module Jobs
  class ToggleTopicClosed < Jobs::Base
    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id] || args[:topic_status_update_id])
      state = !!args[:state]

      if topic_timer.blank? ||
         topic_timer.execute_at > Time.zone.now ||
         (topic = topic_timer.topic).blank? ||
         topic.closed == state

        return
      end

      user = topic_timer.user

      if Guardian.new(user).can_close?(topic)
        topic.update_status('autoclosed', state, user)
        topic.inherit_auto_close_from_category if state == false
      end
    end
  end
end
