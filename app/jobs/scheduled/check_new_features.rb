# frozen_string_literal: true

module Jobs
  class CheckNewFeatures < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      admin_ids = User.human_users.where(admin: true).pluck(:id)

      # Before we download the latest list from Meta:
      #
      # - Some admins have no "last time I looked at new features" stored yet.
      # - If we already have at least one new-feature item saved for this site,
      #   set that stored time for them to the newest thing we know about,
      #   including permanent upcoming changes (those might be newer than the
      #   saved Meta list).
      # - If we have no saved Meta items yet, do not set that time here. Only an
      #   upcoming change might exist; setting the time from that alone would
      #   make us think they are already up to date and we would skip sending the
      #   new-features notification.
      new_features_from_feed = DiscourseUpdates.new_features
      new_features_with_permanent_uc = find_new_features
      prev_most_recent =
        if new_features_from_feed.present?
          new_features_with_permanent_uc&.first&.symbolize_keys || nil
        else
          nil
        end
      if prev_most_recent
        admin_ids.each do |admin_id|
          if DiscourseUpdates.get_last_viewed_feature_date(admin_id).blank?
            DiscourseUpdates.bump_last_viewed_feature_date(admin_id, prev_most_recent[:created_at])
          end
        end
      end

      # This memoization may seem pointless, but it actually avoids us hitting
      # Meta repeatedly and getting rate-limited when this job is ran on a
      # multisite cluster.
      #
      # In multisite, the `execute` method (of the same instance) is called for
      # every site in the cluster.
      @new_features_json ||= DiscourseUpdates.new_features_response_json
      DiscourseUpdates.update_new_features(@new_features_json)

      # After the download is saved:
      #
      # - If an admin has no stored "last looked" time, or it is older than the
      #   newest item (Meta list plus permanent upcoming changes), send the
      #   new-features notification and update their stored time to that newest
      #   item.
      new_features_with_permanent_uc = find_new_features
      new_most_recent = new_features_with_permanent_uc&.first&.symbolize_keys
      if new_most_recent
        most_recent_created_at = new_most_recent[:created_at]
        most_recent_feature_date = Time.zone.parse(most_recent_created_at)

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
            DiscourseUpdates.bump_last_viewed_feature_date(admin_id, most_recent_created_at)
          end
        end
      end
    end

    def find_new_features
      new_features = DiscourseUpdates.new_features
      DiscourseUpdates.merge_new_features_with_upcoming_changes(
        new_features&.map { |item| item.symbolize_keys } || [],
      )
    end
  end
end
