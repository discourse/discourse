module Jobs
  class ToggleTopicClosed < Jobs::Base
    def execute(args)
      topic_status_update = TopicStatusUpdate.find_by(id: args[:topic_status_update_id])
      raise Discourse::InvalidParameters.new(:topic_status_update_id) if topic_status_update.blank?

      return if topic_status_update.execute_at > Time.zone.now

      topic = topic_status_update.topic
      return if topic.blank?

      state = !!args[:state]
      return if topic.closed == state

      user = topic_status_update.user

      if Guardian.new(user).can_close?(topic)
        topic.update_status('autoclosed', state, user)
      end
    end
  end
end
