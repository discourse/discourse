# frozen_string_literal: true

module Jobs
  class GrantAnniversaryBadges < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      return unless SiteSetting.enable_badges?
      badge = Badge.find_by(id: Badge::Anniversary, enabled: true)
      return unless badge

      start_date = args[:start_date] || 1.year.ago
      end_date = start_date + 1.year

      fmt_end_date = end_date.iso8601(6)
      fmt_start_date = start_date.iso8601(6)

      user_ids = DB.query_single <<~SQL
        SELECT u.id AS user_id
        FROM users AS u
        INNER JOIN posts AS p ON p.user_id = u.id
        INNER JOIN topics AS t ON p.topic_id = t.id
        LEFT OUTER JOIN user_badges AS ub ON ub.user_id = u.id AND
          ub.badge_id = #{Badge::Anniversary} AND
          ub.granted_at BETWEEN '#{fmt_start_date}' AND '#{fmt_end_date}'
        WHERE u.active AND
          u.silenced_till IS NULL AND
          NOT p.hidden AND
          p.deleted_at IS NULL AND
          t.visible AND
          t.archetype <> 'private_message' AND
          p.created_at BETWEEN '#{fmt_start_date}' AND '#{fmt_end_date}' AND
          u.created_at <= '#{fmt_start_date}'
        GROUP BY u.id
        HAVING COUNT(p.id) > 0 AND COUNT(ub.id) = 0
      SQL

      User.where(id: user_ids).find_each do |user|
        BadgeGranter.grant(badge, user, created_at: end_date)
      end
    end

  end
end
