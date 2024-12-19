# frozen_string_literal: true

module Jobs
  class EnsureBadgeConsistency < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.enable_badges

      BadgeGranter.revoke_ungranted_titles!
      UserBadge.ensure_consistency! # Badge granter sometimes uses raw SQL, so hooks do not run. Clean up data
      UserStat.update_distinct_badge_count
    end
  end
end
