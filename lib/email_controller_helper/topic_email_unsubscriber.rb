# frozen_string_literal: true

module EmailControllerHelper
  class TopicEmailUnsubscriber < BaseEmailUnsubscriber
    def prepare_unsubscribe_options(controller)
      super(controller)
      watching = TopicUser.notification_levels[:watching]

      topic = unsubscribe_key.associated_topic

      return if topic.blank?

      controller.instance_variable_set(:@topic, topic)
      controller.instance_variable_set(
        :@watching_topic,
        TopicUser.exists?(user: key_owner, notification_level: watching, topic_id: topic.id),
      )

      return if topic.category_id.blank?
      if !CategoryUser.exists?(
           user: key_owner,
           notification_level: CategoryUser.watching_levels,
           category_id: topic.category_id,
         )
        return
      end

      controller.instance_variable_set(
        :@watched_count,
        TopicUser
          .joins(:topic)
          .where(user: key_owner, notification_level: watching)
          .where(topics: { category_id: topic.category_id })
          .count,
      )
    end

    def unsubscribe(params)
      updated = super(params)

      topic = unsubscribe_key.associated_topic
      return updated if topic.nil?

      if params[:unwatch_topic]
        TopicUser.where(topic_id: topic.id, user_id: key_owner.id).update_all(
          notification_level: TopicUser.notification_levels[:tracking],
        )

        updated = true
      end

      if params[:unwatch_category] && topic.category_id
        TopicUser
          .joins(:topic)
          .where(user: key_owner, notification_level: TopicUser.notification_levels[:watching])
          .where(topics: { category_id: topic.category_id })
          .update_all(notification_level: TopicUser.notification_levels[:tracking])

        CategoryUser.where(
          user_id: key_owner.id,
          category_id: topic.category_id,
          notification_level: CategoryUser.watching_levels,
        ).destroy_all

        updated = true
      end

      if params[:mute_topic]
        TopicUser.where(topic_id: topic.id, user_id: key_owner.id).update_all(
          notification_level: TopicUser.notification_levels[:muted],
        )

        updated = true
      end

      updated
    end
  end
end
