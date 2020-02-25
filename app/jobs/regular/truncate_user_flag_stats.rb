# frozen_string_literal: true

class Jobs::TruncateUserFlagStats < ::Jobs::Base

  def self.truncate_to
    100
  end

  # To give users a chance to improve, we limit their flag stats to the last N flags
  def execute(args)
    raise Discourse::InvalidParameters.new(:user_ids) unless args[:user_ids].present?

    args[:user_ids].each do |u|
      user_stat = UserStat.find_by(user_id: u)
      next if user_stat.blank?

      total = user_stat.flags_agreed + user_stat.flags_disagreed + user_stat.flags_ignored
      next if total < self.class.truncate_to

      params = ReviewableScore.statuses.slice(:agreed, :disagreed, :ignored).
        merge(user_id: u, truncate_to: self.class.truncate_to)

      result = DB.query(<<~SQL, params)
        SELECT SUM(CASE WHEN x.status = :agreed THEN 1 ELSE 0 END) AS agreed,
          SUM(CASE WHEN x.status = :disagreed THEN 1 ELSE 0 END) AS disagreed,
          SUM(CASE WHEN x.status = :ignored THEN 1 ELSE 0 END) AS ignored
        FROM (
          SELECT rs.status
          FROM reviewable_scores AS rs
          INNER JOIN reviewables AS r ON r.id = rs.reviewable_id
          INNER JOIN posts AS p ON p.id = r.target_id
          WHERE rs.user_id = :user_id
            AND r.type = 'ReviewableFlaggedPost'
            AND rs.status IN (:agreed, :disagreed, :ignored)
            AND rs.user_id <> p.user_id
          ORDER BY rs.created_at DESC
          LIMIT :truncate_to
        ) AS x
      SQL

      user_stat.update_columns(
        flags_agreed: result[0].agreed || 0,
        flags_disagreed: result[0].disagreed || 0,
        flags_ignored: result[0].ignored || 0,
      )
    end

  end

end
