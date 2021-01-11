# frozen_string_literal: true

module Jobs
  class PublishTopicToCategory < ::Jobs::Base
    def execute(args)
      topic_timer = TopicTimer.find_by(id: args[:topic_timer_id])
      return if topic_timer.blank?

      topic = topic_timer.topic
      return if topic.blank?

      return unless Guardian.new(topic_timer.user).can_see?(topic)

      TopicTimer.transaction do
        TopicPublisher.new(topic, Discourse.system_user, topic_timer.category_id).publish!
      end

      Topic.find(topic.id).inherit_auto_close_from_category
    end
  end
end
