# frozen_string_literal: true

module ::DiscourseGamification
  class LeaderboardCachedView
    class NotReadyError < StandardError
    end

    SCORE_RANKING_STRATEGY_MAP = {
      row_number: "ROW_NUMBER()",
      rank: "RANK()",
      dense_rank: "DENSE_RANK()",
    }.freeze
    PERIOD_INTERVALS = {
      "yearly" => "CURRENT_DATE - INTERVAL '1 year'",
      "quarterly" => "CURRENT_DATE - INTERVAL '3 months'",
      "monthly" => "CURRENT_DATE - INTERVAL '1 month'",
      "weekly" => "CURRENT_DATE - INTERVAL '1 week'",
      "daily" => "CURRENT_DATE - INTERVAL '1 day'",
    }.freeze

    attr_reader :leaderboard

    def initialize(leaderboard)
      @leaderboard = leaderboard
    end

    def create
      periods.each { |period| create_mview(period) }
    end

    def refresh
      periods.each { |period| refresh_mview(period) }
    end

    def delete
      periods.each { |period| delete_mview(period) }
    end

    def purge_stale
      list = stale_mviews

      return if list.empty?

      DB.exec("DROP MATERIALIZED VIEW IF EXISTS #{list.join(", ")} CASCADE")
    end

    def stale?
      stale_mviews.present?
    end

    def scores(period: "all_time", page: 0, for_user_id: false, limit: nil, offset: nil)
      user_filter_condition = for_user_id ? ["users.id = ?", for_user_id] : [nil]

      if mview_exists?(period)
        User
          .where(*user_filter_condition)
          .joins("INNER JOIN #{mview_name(period)} p ON  p.user_id = users.id")
          .select(
            "users.id, users.name, users.username, users.uploaded_avatar_id, p.total_score, p.position",
          )
          .limit(limit)
          .offset(offset)
          .order(position: :asc, id: :asc)
          .load
      else
        raise NotReadyError.new(I18n.t("errors.leaderboard_positions_not_ready"))
      end
    end

    def self.create_all
      GamificationLeaderboard.find_each { |leaderboard| self.new(leaderboard).create }
    end

    def self.refresh_all
      GamificationLeaderboard.find_each { |leaderboard| self.new(leaderboard).refresh }
    end

    def self.delete_all
      GamificationLeaderboard.find_each { |leaderboard| self.new(leaderboard).delete }
    end

    def self.purge_all_stale
      GamificationLeaderboard.find_each { |leaderboard| self.new(leaderboard).purge_stale }
    end

    def self.update_all
      ActiveRecord::Base.transaction do
        purge_all_stale
        create_all
      end
    end

    def self.regenerate_all
      ActiveRecord::Base.transaction do
        delete_all
        create_all
      end
    end

    private

    def create_mview(period)
      return if mview_exists?(period)

      name = mview_name(period)
      select_query = total_scores_query(period)

      mview_query = <<~SQL
        CREATE MATERIALIZED VIEW IF NOT EXISTS #{name} AS
        #{select_query}
      SQL

      user_id_index_query = <<~SQL
        CREATE UNIQUE INDEX IF NOT EXISTS user_id_#{leaderboard.id}_#{period}_index ON #{name} (user_id)
      SQL

      ActiveRecord::Base.transaction do
        DB.exec(mview_query, leaderboard_id: leaderboard.id)
        DB.exec(user_id_index_query)
        DB.exec("COMMENT ON MATERIALIZED VIEW #{name} IS '#{query_signature(select_query)}'")
      end
    end

    def total_scores_query(period)
      <<~SQL
        WITH leaderboard AS (
          SELECT * FROM gamification_leaderboards WHERE id = :leaderboard_id
        ),

        leaderboard_users AS (
          SELECT
            u.id
          FROM
            users u
          INNER JOIN
            user_emails ON user_emails.primary = TRUE AND user_emails.user_id = u.id
          CROSS JOIN
            leaderboard lb
          WHERE NOT
            (user_emails.email LIKE '%@anonymized.invalid%')
          AND
            u.staged = FALSE
          AND
            u.active
          AND 
            (u.suspended_till IS NULL OR u.suspended_till < CURRENT_TIMESTAMP)
          AND
            u.id > 0
          AND
            (
              NOT EXISTS(SELECT 1 FROM anonymous_users a WHERE a.user_id = u.id)
            )
          AND
            -- Ensure user is a member of included_groups_ids if it's not empty
            (
              (COALESCE(array_length(lb.included_groups_ids, 1), 0) = 0)
              OR
              (EXISTS (SELECT 1 FROM group_users AS gu WHERE gu.group_id = ANY(lb.included_groups_ids) AND gu.user_id = u.id))
            )
          AND
            -- Ensure user is not a member of excluded_groups_ids if it's not empty
            (
              (COALESCE(array_length(lb.excluded_groups_ids, 1), 0) = 0)
              OR
              (NOT EXISTS (SELECT 1 FROM group_users AS gu WHERE gu.group_id = ANY(lb.excluded_groups_ids) AND gu.user_id = u.id))
            )
        ),

        scores AS (
          SELECT
            gs.*
          FROM
            gamification_scores gs
          CROSS JOIN
            leaderboard lb
          WHERE
            (CASE
              -- Leaderboard with both "to_date" and "from_date" configured.
              -- Filter scores within the configured date range AND
              -- the relative period window
              WHEN lb.from_date IS NOT NULL AND lb.to_date IS NOT NULL THEN
                gs.date BETWEEN GREATEST(lb.from_date, #{period_start_sql(period)}) AND lb.to_date

              -- Leaderboard with only "from_date" configured.
              -- Filter scores starting from the later of leaderboard's "from_date"
              -- and the relative period start date
              WHEN lb.from_date IS NOT NULL AND lb.to_date IS NULL THEN
                gs.date >= GREATEST(lb.from_date, #{period_start_sql(period)})

              -- Leaderboard with only "to_date" configured.
              -- Filter scores up to leaderboard's "to_date" starting from
              -- the relative period start date
              WHEN lb.from_date IS NULL AND lb.to_date IS NOT NULL THEN
                gs.date >= COALESCE(#{period_start_sql(period)}, gs.date) AND gs.date <= lb.to_date

              -- Leaderboard with no "from_date" and "to_date" configured.
              -- Filter scores within the relative period window only
              ELSE
                gs.date >= COALESCE(#{period_start_sql(period)}, gs.date)
            END)
            AND gs.date <= CURRENT_DATE -- Ensure scores are not from the future
        )

        SELECT
         lu.id AS user_id,
         SUM(COALESCE(s.score, 0)) AS total_score,
         #{ranking_function} OVER (ORDER BY SUM(COALESCE(s.score, 0)) DESC) AS position
        FROM
          leaderboard_users lu
        INNER JOIN
          scores s ON s.user_id = lu.id
        GROUP BY
          lu.id
        ORDER BY
          position ASC,
          user_id ASC
      SQL
    end

    def ranking_function
      SCORE_RANKING_STRATEGY_MAP[SiteSetting.score_ranking_strategy.to_sym]
    end

    def refresh_mview(period)
      return unless mview_exists?(period)

      DB.exec("REFRESH MATERIALIZED VIEW CONCURRENTLY #{mview_name(period)}")
    end

    def mview_exists?(period)
      DB.query_single(<<~SQL).first
        SELECT EXISTS (
          SELECT 1 FROM pg_matviews
          WHERE schemaname = current_schema() AND matviewname = '#{mview_name(period)}'
        )
      SQL
    end

    def delete_mview(period)
      DB.exec("DROP MATERIALIZED VIEW IF EXISTS #{mview_name(period)} CASCADE")
    end

    def mview_name(period)
      "gamification_leaderboard_cache_#{leaderboard.id}_#{period}"
    end

    def periods
      @periods ||= GamificationLeaderboard.periods.keys
    end

    def stale_mviews
      return [] if periods.none? { |period| stale_mview?(period) }

      # There shouldn't be case where only some of the mviews are stale
      periods.map { |period| mview_name(period) }
    end

    def stale_mview?(period)
      return false unless mview_exists?(period)

      current_signature = DB.query_single(<<~SQL).first
        SELECT obj_description('#{mview_name(period)}'::regclass::oid, 'pg_class')
      SQL

      # If for some reason there is no signature, assume it's stale
      return true if current_signature.nil?

      current_signature != query_signature(total_scores_query(period))
    end

    def query_signature(query)
      Digest::SHA256.hexdigest(query.strip.gsub(/\s+/, " "))
    end

    def period_start_sql(period)
      PERIOD_INTERVALS[period] || "NULL"
    end
  end
end
