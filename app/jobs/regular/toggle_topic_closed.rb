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
        if state == false && PostAction.auto_close_threshold_reached?(topic)
          topic.set_or_create_timer(
            TopicTimer.types[:open],
            SiteSetting.num_hours_to_close_topic,
            by_user: Discourse.system_user
          )
        else
          topic.update_status('autoclosed', state, user)
        end

        topic.inherit_auto_close_from_category if state == false
      end
    end
  end
end
