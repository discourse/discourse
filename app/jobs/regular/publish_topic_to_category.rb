# frozen_string_literal: true

module Jobs
  class PublishTopicToCategory < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      return unless Guardian.new(topic_timer.user).can_see?(topic)

      TopicTimer.transaction do
        TopicPublisher.new(topic, Discourse.system_user, topic_timer.category_id).publish!
      end

      Topic.find(topic.id).inherit_topic_timer_from_category
    end
  end
end
