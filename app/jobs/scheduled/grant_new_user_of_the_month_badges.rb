require 'badge_granter'

module Jobs
  class GrantNewUserOfTheMonthBadges < Jobs::Scheduled
    every 1.month

    MAX_AWARDED = 2

    def execute(args)
      badge = Badge.find(Badge::NewUserOfTheMonth)
      scores.each do |user_id, score|
        # Don't bother awarding to users who haven't received any likes
        if score > 0.0
          user = User.find(user_id)
          if user.badges.where(id: Badge::NewUserOfTheMonth).blank?
            BadgeGranter.grant(badge, user)
            SystemMessage.new(user).create('new_user_of_the_month', {
              month_year: Time.now.strftime("%B %Y")
            })
          end
        end
      end
    end

    def scores
      scores = {}

      # Find recent accounts and come up with a score based on how many likes they
      # received, based on how much they posted and how old the accounts of the people
      # who voted on them are.
      sql = <<~SQL
        SELECT u.id,
          SUM(CASE
               WHEN pa.id IS NOT NULL THEN
                 CASE
                   WHEN liked_by.created_at > (CURRENT_TIMESTAMP - '1 week'::INTERVAL) THEN 0.1
                   WHEN liked_by.created_at > (CURRENT_TIMESTAMP - '1 month'::INTERVAL) THEN 0.5
                   ELSE 1.0
                 END
               ELSE 0
              END) / COUNT(DISTINCT p.id) AS score
        FROM users AS u
        INNER JOIN user_stats AS us ON u.id = us.user_id
        LEFT OUTER JOIN posts AS p ON p.user_id = u.id
        LEFT OUTER JOIN post_actions AS pa ON
          pa.post_id = p.id AND pa.post_action_type_id = :like
        LEFT OUTER JOIN users AS liked_by ON liked_by.id = pa.user_id
        WHERE u.active AND
          u.id > 0 AND
          NOT(u.admin) AND
          NOT(u.moderator) AND
          u.created_at >= CURRENT_TIMESTAMP - '1 month'::INTERVAL
        GROUP BY u.id
        HAVING COUNT(DISTINCT p.id) > 3 AND COUNT(DISTINCT p.topic_id) > 1
        ORDER BY score DESC
        LIMIT :max_awarded
      SQL

      User.exec_sql(sql, {
        like: PostActionType.types[:like],
        max_awarded: MAX_AWARDED
      }).each do |row|
        scores[row['id'].to_i] = row['score'].to_f
      end
      scores
    end

  end
end
