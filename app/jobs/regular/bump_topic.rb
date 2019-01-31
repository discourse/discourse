module Jobs
  class BumpTopic < Jobs::Base

    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id] || args[:topic_status_update_id])

      topic = topic_timer&.topic

      if topic_timer.blank? || topic.blank? || topic_timer.execute_at > Time.zone.now
        return
      end

      if Guardian.new(topic_timer.user).can_create_post_on_topic?(topic)
        topic.add_small_action(Discourse.system_user, "autobumped", nil, bump: true)
      end
      topic_timer.trash!(Discourse.system_user)
    end

  end
end
