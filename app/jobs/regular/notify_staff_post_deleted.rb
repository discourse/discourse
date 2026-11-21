# frozen_string_literal: true

module Jobs
  class NotifyStaffPostDeleted < ::Jobs::Base
    def execute(args)
      group_ids = SiteSetting.staff_post_deletion_notification_groups_map
      return if group_ids.blank?

      history =
        UserHistory.find_by(id: args[:history_id], action: UserHistory.actions[:delete_post])
      return if history.nil?

      post = Post.with_deleted.includes(topic: :category).find_by(id: history.post_id)
      if !post&.trashed? || post.post_type != Post.types[:regular] || !post.topic&.regular? ||
           post.user_id == history.acting_user_id
        return
      end

      DistributedMutex.synchronize("notify_staff_post_deleted_#{history.id}") do
        notify_staff(history, post.topic, group_ids)
      end
    end

    private

    def notify_staff(history, topic, group_ids)
      notification_type = Notification.types[:staff_post_deleted]
      data = { staff_action_id: history.id }.to_json
      notified_ids =
        Notification.where(topic_id: topic.id, notification_type:, data:).pluck(:user_id)
      staff =
        User
          .human_users
          .where(active: true)
          .where("admin OR moderator")
          .where("suspended_till IS NULL OR suspended_till <= ?", Time.zone.now)
          .where.not(id: [history.acting_user_id, *notified_ids])

      if group_ids.exclude?(Group::AUTO_GROUPS[:logged_in_users]) &&
           (
             group_ids.exclude?(Group::AUTO_GROUPS[:everyone]) ||
               SiteSetting.granular_anonymous_and_logged_in_groups_permissions
           )
        staff = staff.where(id: GroupUser.where(group_id: group_ids).select(:user_id))
      end

      staff.find_in_batches do |batch|
        records =
          batch.filter_map do |user|
            if user.guardian.can_see_topic?(topic)
              { user_id: user.id, topic_id: topic.id, notification_type:, data: }
            end
          end
        Notification::Action::BulkCreate.call(records:, skip_send_email: true)
      end
    end
  end
end
