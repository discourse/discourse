# frozen_string_literal: true

module Jobs
  class GrantAnniversaryBadges < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges?
      return unless badge = Badge.find_by(id: Badge::Anniversary, enabled: true)

      start_date = args[:start_date] || 1.year.ago
      end_date = start_date + 1.year

      sql = BadgeQueries.anniversaries(start_date, end_date)
      grants = DB.query(sql).to_h { |grant| [grant.user_id, grant.granted_at] }

      User
        .where(id: grants.keys)
        .find_each { |user| BadgeGranter.grant(badge, user, created_at: grants[user.id]) }
    end
  end
end
