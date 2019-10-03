# frozen_string_literal: true

class Jobs::ReviewablePriorities < ::Jobs::Scheduled
  every 1.day

  # We need this many reviewables before we'll calculate priorities
  def self.min_reviewables
    15
  end

  # We want to look at scores for items with this many reviewables (flags) attached
  def self.target_count
    2
  end

  def execute(args)
    return unless Reviewable.where('score > 0').count >= self.class.min_reviewables

    res = DB.query_single(<<~SQL, target_count: self.class.target_count)
      SELECT COALESCE(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY score), 0.0) AS medium,
        COALESCE(PERCENTILE_DISC(0.85) WITHIN GROUP (ORDER BY score), 0.0) AS high
      FROM (
        SELECT r.score
        FROM reviewables AS r
        INNER JOIN reviewable_scores AS rs ON rs.reviewable_id = r.id
        GROUP BY r.id
        HAVING COUNT(*) >= :target_count
      ) AS x
    SQL

    return unless res && res.size == 2

    medium, high = res

    Reviewable.set_priorities(medium: medium, high: high)
  end
end
