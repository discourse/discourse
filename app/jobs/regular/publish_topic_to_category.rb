# frozen_string_literal: true

module Jobs
  class PublishTopicToCategory < ::Jobs::TopicTimerBase
    def execute_timer_action(topic_timer, topic)
      user = topic_timer.user
      guardian = Guardian.new(user)
      category = topic_timer.category

      return if category.blank?
      return unless guardian.can_set_topic_timer?(topic)
      return unless guardian.can_create_topic_on_category?(category)
      return if topic.private_message? && !guardian.can_convert_topic?(topic)

      TopicTimer.transaction { TopicPublisher.new(topic, user, category.id).publish! }

      Topic.find(topic.id).inherit_auto_close_from_category
    end
  end
end
