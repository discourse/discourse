# frozen_string_literal: true

module Jobs
  class PublishTopicToCategory < ::Jobs::Base
    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id] || args[:topic_status_update_id])
      return if topic_timer.blank?

      topic = topic_timer.topic
      return if topic.blank?

      TopicTimer.transaction do
        TopicPublisher.new(topic, Discourse.system_user, topic_timer.category_id).publish!
      end
    end
  end
end
