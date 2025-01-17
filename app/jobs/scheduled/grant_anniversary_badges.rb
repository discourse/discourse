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
      user_ids_to_anniversary_dates = DB.query_array(sql).to_h

      User
        .where(id: user_ids_to_anniversary_dates.keys)
        .find_each do |user|
          anniversary_date = user_ids_to_anniversary_dates[user.id] || start_date
          years_ago = Date.today.year - anniversary_date.year
          BadgeGranter.grant(badge, user, created_at: anniversary_date.advance(years: years_ago))
        end
    end
  end
end
