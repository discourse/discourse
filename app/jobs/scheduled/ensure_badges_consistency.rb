# frozen_string_literal: true

module Jobs
  class EnsureBadgesConsistency < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges

      BadgeGranter.revoke_ungranted_titles!
      UserBadge.ensure_consistency!
      UserStat.update_distinct_badge_count
    end
  end
end
