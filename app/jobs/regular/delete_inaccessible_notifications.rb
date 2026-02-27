# frozen_string_literal: true

module Jobs
  class DeleteInaccessibleNotifications < ::Jobs::Base
    def execute(args)
      if args[:topic_id].present?
        cleanup_for_topic(args[:topic_id])
      elsif args[:category_id].present?
        cleanup_for_category(args[:category_id])
      elsif args[:user_id].present? && args[:group_id].present?
        cleanup_for_user_group_removal(args[:user_id], args[:group_id])
      end
    end

    private

    def cleanup_for_category(category_id)
      Topic.where(category_id: category_id).find_each { |topic| cleanup_for_topic(topic.id) }
    end

    def cleanup_for_topic(topic_id)
      Notification
        .where(topic_id: topic_id)
        .find_each do |notification|
          next unless notification.user && notification.topic
          notification.destroy if !Guardian.new(notification.user).can_see?(notification.topic)
        end
    end

    def cleanup_for_user_group_removal(user_id, group_id)
      user = User.find_by(id: user_id)
      return unless user

      guardian = Guardian.new(user)

      # Find topics accessible via that group: PMs where group was allowed + restricted category topics
      topic_ids =
        Notification
          .where(user_id: user_id)
          .where.not(topic_id: nil)
          .joins("JOIN topics t ON t.id = notifications.topic_id")
          .where(
            "(t.archetype = 'private_message' AND t.id IN (SELECT topic_id FROM topic_allowed_groups WHERE group_id = :group_id))
             OR (t.archetype != 'private_message' AND t.category_id IN (SELECT category_id FROM category_groups WHERE group_id = :group_id))",
            group_id: group_id,
          )
          .distinct
          .pluck(:topic_id)

      topic_ids.each do |topic_id|
        topic = Topic.find_by(id: topic_id)
        next unless topic

        unless guardian.can_see?(topic)
          Notification.where(user_id: user_id, topic_id: topic_id).delete_all
        end
      end
    end
  end
end
