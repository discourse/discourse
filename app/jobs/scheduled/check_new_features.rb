# frozen_string_literal: true

module Jobs
  class CheckNewFeatures < ::Jobs::Scheduled
    every 1.hour

    def execute(args)
      admin_ids = User.human_users.where(admin: true).pluck(:id)

      prev_most_recent = DiscourseUpdates.new_features&.first
      if prev_most_recent
        admin_ids.each do |admin_id|
          if DiscourseUpdates.get_last_viewed_feature_date(admin_id).blank?
            DiscourseUpdates.bump_last_viewed_feature_date(admin_id, prev_most_recent["created_at"])
          end
        end
      end

      # this memoization may seem pointless, but it actually avoids us hitting
      # Meta repeatedly and getting rate-limited when this job is ran on a
      # multisite cluster.
      # in multisite, the `execute` method (of the same instance) is called for
      # every site in the cluster.
      @new_features_json ||= DiscourseUpdates.new_features_payload
      DiscourseUpdates.update_new_features(@new_features_json)

      new_most_recent = DiscourseUpdates.new_features&.first
      if new_most_recent
        most_recent_feature_date = Time.zone.parse(new_most_recent["created_at"])
        admin_ids.each do |admin_id|
          admin_last_viewed_feature_date = DiscourseUpdates.get_last_viewed_feature_date(admin_id)
          if admin_last_viewed_feature_date.blank? ||
               admin_last_viewed_feature_date < most_recent_feature_date
            Notification.consolidate_or_create!(
              user_id: admin_id,
              notification_type: Notification.types[:new_features],
              data: {
              },
            )
            DiscourseUpdates.bump_last_viewed_feature_date(admin_id, new_most_recent["created_at"])
          end
        end
      end
    end
  end
end
