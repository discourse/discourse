require_dependency 'jobs/scheduled/grant_anniversary_badges'

module Jobs

  class FixRetroAnniversary < Jobs::Onceoff
    def execute_onceoff(args)
      return unless SiteSetting.enable_badges

      users = DB.query <<~SQL
        SELECT ub.user_id, MIN(granted_at) AS first_granted_at, COUNT(*) count
        FROM user_badges AS ub
        WHERE ub.badge_id = #{Badge::Anniversary}
        GROUP BY ub.user_id
        HAVING COUNT(ub.id) > 1
      SQL

      users.each do |u|
        first = u.first_granted_at
        badges = UserBadge.where(
          "badge_id = ? AND user_id = ? AND granted_at > ?",
          Badge::Anniversary,
          u.user_id,
          first
        ).order('granted_at')

        badges.each_with_index do |b, idx|
          award_date = (first + (idx + 1).years)
          UserBadge.where(id: b.id).update_all(["granted_at = ?", award_date])
        end
      end

    end
  end
end
