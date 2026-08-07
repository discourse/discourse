# frozen_string_literal: true

module Jobs
  class DeleteInaccessibleNotifications < ::Jobs::Base
    def execute(args)
      raise Discourse::InvalidParameters.new(:topic_id) if args[:topic_id].blank?

      topic = Topic.find_by(id: args[:topic_id])
      return if topic.blank?

      user_ids = args[:user_ids].presence
      user_ids ||= Notification.where(topic_id: topic.id).distinct.pluck(:user_id)
      return if user_ids.blank?

      inaccessible_users = User.where(id: user_ids).reject { |user| user.guardian.can_see?(topic) }
      return if inaccessible_users.empty?

      Notification.where(user_id: inaccessible_users.map(&:id), topic_id: topic.id).delete_all
      inaccessible_users.each(&:publish_notifications_state)
    end
  end
end
