module Jobs
  class PublishTopicToCategory < Jobs::Base
    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id] || args[:topic_status_update_id])
      return if topic_timer.blank?

      topic = topic_timer.topic
      return if topic.blank?

      TopicTimestampChanger.new(timestamp: Time.zone.now, topic: topic).change! do
        if topic.private_message?
          topic = TopicConverter.new(topic, Discourse.system_user)
            .convert_to_public_topic(topic_timer.category_id)
        else
          topic.change_category_to_id(topic_timer.category_id)
        end

        topic.update_columns(visible: true)
        topic_timer.trash!(Discourse.system_user)
      end

      MessageBus.publish("/topic/#{topic.id}", reload_topic: true, refresh_stream: true)
    end
  end
end
