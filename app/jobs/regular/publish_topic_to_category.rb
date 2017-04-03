module Jobs
  class PublishTopicToCategory < Jobs::Base
    def execute(args)
      topic_status_update = TopicStatusUpdate.find_by(id: args[:topic_status_update_id])
      raise Discourse::InvalidParameters.new(:topic_status_update_id) if topic_status_update.blank?

      topic = topic_status_update.topic
      return if topic.blank?

      PostTimestampChanger.new(timestamp: Time.zone.now, topic: topic).change! do
        topic.change_category_to_id(topic_status_update.category_id)
      end
    end
  end
end
