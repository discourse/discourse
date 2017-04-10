module Jobs
  class ToggleTopicClosed < Jobs::Base
    def execute(args)
      topic_status_update = TopicStatusUpdate.find_by(id: args[:topic_status_update_id])
      state = !!args[:state]

      if topic_status_update.blank? ||
         topic_status_update.execute_at > Time.zone.now ||
         (topic = topic_status_update.topic).blank? ||
         topic.closed == state

        return
      end

      user = topic_status_update.user

      if Guardian.new(user).can_close?(topic)
        topic.update_status('autoclosed', state, user)
      end
    end
  end
end
