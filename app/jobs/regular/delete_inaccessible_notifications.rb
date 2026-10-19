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

      inaccessible_ids = inaccessible_user_ids(topic, user_ids)
      return if inaccessible_ids.empty?

      Notification.where(user_id: inaccessible_ids, topic_id: topic.id).delete_all
      User.where(id: inaccessible_ids).find_each(&:publish_notifications_state)
    end

    private

    # For PMs (the common case) resolve access with two set-based queries instead
    # of one Guardian#can_see? call per user, so a job on a large group PM does
    # not fan out into N SQL round-trips.
    def inaccessible_user_ids(topic, user_ids)
      return per_user_guardian_check(topic, user_ids) if !topic.private_message? || topic.deleted_at

      accessible_ids = topic.all_allowed_users.where(id: user_ids).pluck(:id)
      if !SiteSetting.suppress_secured_categories_from_admin
        accessible_ids |= User.where(id: user_ids, admin: true).pluck(:id)
      end
      user_ids - accessible_ids
    end

    def per_user_guardian_check(topic, user_ids)
      User.where(id: user_ids).reject { |u| u.guardian.can_see?(topic) }.map(&:id)
    end
  end
end
