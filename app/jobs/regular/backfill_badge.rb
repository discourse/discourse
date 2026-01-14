# frozen_string_literal: true

module Jobs
  class BackfillBadge < ::Jobs::Base
    sidekiq_options queue: "low"
    # The queries executed by this job can be expensive so limit the concurrency to 1 per cluster
    cluster_concurrency 1

    def execute(args)
      return unless SiteSetting.enable_badges

      badge = Badge.enabled.find_by(id: args[:badge_id])
      return unless badge

      revoked_user_ids = Set.new
      granted_user_ids = Set.new

      BadgeGranter.backfill(
        badge,
        revoked_callback: ->(user_ids) { revoked_user_ids.merge(user_ids) },
        granted_callback: ->(user_ids) { granted_user_ids.merge(user_ids) },
      )

      affected_user_ids = (revoked_user_ids | granted_user_ids).to_a
      revoked_user_ids = revoked_user_ids.to_a

      BadgeGranter.revoke_ungranted_titles!(revoked_user_ids) if revoked_user_ids.present?

      if affected_user_ids.present?
        UserBadge.ensure_consistency!(affected_user_ids)
        UserStat.update_distinct_badge_count(affected_user_ids)
      end
    end
  end
end
