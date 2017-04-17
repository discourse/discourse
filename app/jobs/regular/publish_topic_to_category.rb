module Jobs
  class PublishTopicToCategory < Jobs::Base
    def execute(args)
      topic_status_update = TopicStatusUpdate.find_by(id: args[:topic_status_update_id])
      raise Discourse::InvalidParameters.new(:topic_status_update_id) if topic_status_update.blank?

      topic = topic_status_update.topic
      return if topic.blank?

      PostTimestampChanger.new(timestamp: Time.zone.now, topic: topic).change! do
        if topic.private_message?
          topic = TopicConverter.new(topic, Discourse.system_user)
            .convert_to_public_topic(topic_status_update.category_id)
        else
          topic.change_category_to_id(topic_status_update.category_id)
        end

        topic.update_columns(visible: true)
        topic_status_update.trash!(Discourse.system_user)
      end

      MessageBus.publish("/topic/#{topic.id}", reload_topic: true, refresh_stream: true)
    end
  end
end
