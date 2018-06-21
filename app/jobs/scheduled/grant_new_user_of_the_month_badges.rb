require 'badge_granter'

module Jobs
  class GrantNewUserOfTheMonthBadges < Jobs::Scheduled
    every 1.day

    MAX_AWARDED = 2

    def execute(args)
      badge = Badge.find(Badge::NewUserOfTheMonth)
      return unless SiteSetting.enable_badges? && badge.enabled?

      # Don't award it if a month hasn't gone by
      return if UserBadge.where("badge_id = ? AND granted_at >= ?",
        badge.id,
        (1.month.ago + 1.day)  # give it a day slack just in case
      ).exists?

      scores.each do |user_id, score|
        # Don't bother awarding to users who haven't received any likes
        if score > 0.0
          user = User.find(user_id)
          if user.badges.where(id: Badge::NewUserOfTheMonth).blank?
            BadgeGranter.grant(badge, user)

            SystemMessage.new(user).create('new_user_of_the_month',
              month_year: Time.now.strftime("%B %Y"),
              url: "#{Discourse.base_url}/badges"
            )
          end
        end
      end
    end

    def scores
      current_owners = UserBadge.where(badge_id: Badge::NewUserOfTheMonth).pluck(:user_id)
      current_owners = [-1] if current_owners.blank?

      # Find recent accounts and come up with a score based on how many likes they
      # received, based on how much they posted and how old the accounts of the people
      # who voted on them are.
      sql = <<~SQL
        SELECT u.id,
          SUM(CASE
              WHEN pa.id IS NOT NULL THEN
                CASE
                WHEN liked_by.id <= 0         THEN 0.0
                WHEN liked_by.admin           THEN 3.0
                WHEN liked_by.moderator       THEN 3.0
                WHEN liked_by.trust_level = 4 THEN 2.0
                WHEN liked_by.trust_level = 3 THEN 1.5
                WHEN liked_by.trust_level = 2 THEN 1.0
                WHEN liked_by.trust_level = 1 THEN 0.25
                WHEN liked_by.trust_level = 0 THEN 0.1
                ELSE 1.0
                END
              ELSE 0
              END) / (5 + COUNT(DISTINCT p.id))::float AS score
        FROM users AS u
        INNER JOIN user_stats        AS us       ON u.id = us.user_id
        LEFT OUTER JOIN posts        AS p        ON p.user_id = u.id
        LEFT OUTER JOIN post_actions AS pa       ON pa.post_id = p.id AND pa.post_action_type_id = #{PostActionType.types[:like]}
        LEFT OUTER JOIN users        AS liked_by ON liked_by.id = pa.user_id
        LEFT OUTER JOIN topics       AS t        ON t.id = p.topic_id
        WHERE u.active
          AND u.id > 0
          AND u.id NOT IN (#{current_owners.join(',')})
          AND NOT u.staged
          AND NOT u.admin
          AND NOT u.moderator
          AND u.suspended_at IS NULL
          AND u.suspended_till IS NULL
          AND u.created_at >= CURRENT_TIMESTAMP - '1 month'::INTERVAL
          AND t.archetype <> '#{Archetype.private_message}'
          AND t.deleted_at IS NULL
          AND p.deleted_at IS NULL
        GROUP BY u.id
        HAVING COUNT(DISTINCT p.id) > 1
           AND COUNT(DISTINCT p.topic_id) > 1
           AND COUNT(pa.id) > 1
        ORDER BY score DESC
        LIMIT #{MAX_AWARDED}
      SQL

      Hash[*DB.query_single(sql)]
    end

  end
end
