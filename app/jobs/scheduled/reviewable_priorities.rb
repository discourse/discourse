# frozen_string_literal: true

class Jobs::ReviewablePriorities < Jobs::Scheduled
  every 1.day

  def execute(args)

    # We calculate the percentiles here for medium and high. Low is always 0 (all)
    res = DB.query_single(<<~SQL)
      SELECT COALESCE(PERCENTILE_DISC(0.4) WITHIN GROUP (ORDER BY score), 0.0) AS medium,
        COALESCE(PERCENTILE_DISC(0.8) WITHIN GROUP (ORDER BY score), 0.0) AS high
        FROM reviewables
    SQL

    Reviewable.set_priorities(medium: res[0], high: res[1])
  end
end
