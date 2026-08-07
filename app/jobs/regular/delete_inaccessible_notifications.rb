# frozen_string_literal: true

module Jobs
  class DeleteInaccessibleNotifications < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?

      topic = Topic.find_by(id: args[:topic_id])
      return if topic.blank?

      scope = Notification.where(topic_id: topic.id)
      scope = scope.where(user_id: args[:user_ids]) if args[:user_ids].present?
      user_ids = scope.distinct.pluck(:user_id)
      return if user_ids.empty?

      User
        .where(id: user_ids)
        .find_each do |user|
          next if user.guardian.can_see?(topic)

          removed_count = Notification.where(user_id: user.id, topic_id: topic.id).delete_all
          user.publish_notifications_state if removed_count.positive?
        end
    end
  end
end
