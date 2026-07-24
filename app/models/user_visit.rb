# frozen_string_literal: true

class UserVisit < ActiveRecord::Base
  belongs_to :user

  def self.counts_by_day_query(start_date, end_date, group_id = nil)
    result = where("visited_at >= ? and visited_at <= ?", start_date.to_date, end_date.to_date)

    if group_id
      result = result.joins("INNER JOIN users ON users.id = user_visits.user_id")
      result = result.joins("INNER JOIN group_users ON group_users.user_id = users.id")
      result = result.where("group_users.group_id = ?", group_id)
    end
    result.group(:visited_at).order(:visited_at)
  end

  def self.count_by_active_users(start_date, end_date)
    sql = <<~SQL
      WITH island_boundaries AS (
        -- A user's visit days merge into an "active island" when gaps are
        -- 30 days or less; the user counts toward MAU from each island's
        -- start until 29 days after its end. A row is an island start when
        -- the previous visit is too far back, an island end when the next
        -- visit is too far ahead.
        SELECT d, prev_d, next_d
        FROM (
          SELECT
            visited_at AS d,
            lag(visited_at) OVER w AS prev_d,
            lead(visited_at) OVER w AS next_d
          FROM user_visits
          WHERE visited_at >= :start_date::DATE - 29
            AND visited_at <= :end_date::DATE
          WINDOW w AS (PARTITION BY user_id ORDER BY visited_at)
        ) visits
        WHERE prev_d IS NULL OR prev_d < d - 30
          OR next_d IS NULL OR next_d > d + 30
      ),
      active_range_events AS (
        SELECT d AS day, 1 AS delta
        FROM island_boundaries
        WHERE prev_d IS NULL OR prev_d < d - 30
        UNION ALL
        SELECT d + 30 AS day, -1 AS delta
        FROM island_boundaries
        WHERE next_d IS NULL OR next_d > d + 30
      ),
      daily_active_deltas AS (
        SELECT day, sum(delta) AS delta
        FROM active_range_events
        GROUP BY day
      ),
      days AS (
        SELECT generate_series(
          (SELECT min(day) FROM daily_active_deltas),
          :end_date::DATE,
          INTERVAL '1 day'
        )::DATE AS day
      ),
      rolling_mau AS (
        SELECT days.day,
          sum(coalesce(daily_active_deltas.delta, 0)) OVER (ORDER BY days.day) AS mau
        FROM days
        LEFT JOIN daily_active_deltas ON daily_active_deltas.day = days.day
      ),
      dau AS (
        SELECT visited_at AS date, count(*) AS dau
        FROM user_visits
        WHERE visited_at >= :start_date::DATE
          AND visited_at <= :end_date::DATE
        GROUP BY visited_at
      )
      SELECT dau.date, dau.dau, rolling_mau.mau
      FROM dau
      JOIN rolling_mau ON rolling_mau.day = dau.date
      ORDER BY dau.date
    SQL

    DB.query_hash(sql, start_date: start_date, end_date: end_date)
  end

  # A count of visits in a date range by day
  def self.by_day(start_date, end_date, group_id = nil)
    counts_by_day_query(start_date, end_date, group_id).count
  end

  def self.mobile_by_day(start_date, end_date, group_id = nil)
    counts_by_day_query(start_date, end_date, group_id).where(mobile: true).count
  end

  def self.counts_by_day_and_mobile(start_date, end_date, group_id: nil)
    sql = <<~SQL
      SELECT
        visited_at,
        mobile,
        COUNT(*) AS visit_count,
        SUM(COUNT(*)) OVER () AS total
      FROM user_visits
      #{"INNER JOIN group_users ON group_users.user_id = user_visits.user_id" if group_id}
      WHERE visited_at >= :start_date AND visited_at <= :end_date
      #{"AND group_users.group_id = :group_id" if group_id}
      GROUP BY visited_at, mobile
      ORDER BY visited_at
    SQL

    params = { start_date: start_date, end_date: end_date, prev_start: start_date - 30.days }
    params[:group_id] = group_id.to_i if group_id

    DB.query(sql, **params)
  end

  def self.ensure_consistency!
    DB.exec <<~SQL
      UPDATE user_stats u set days_visited =
      (
        SELECT COUNT(*) FROM user_visits v WHERE v.user_id = u.user_id
      )
      WHERE days_visited <>
      (
        SELECT COUNT(*) FROM user_visits v WHERE v.user_id = u.user_id
      )
    SQL
  end
end

# == Schema Information
#
# Table name: user_visits
#
#  id         :integer          not null, primary key
#  mobile     :boolean          default(FALSE)
#  posts_read :integer          default(0)
#  time_read  :integer          default(0), not null
#  visited_at :date             not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_user_visits_on_user_id_and_visited_at                (user_id,visited_at) UNIQUE
#  index_user_visits_on_user_id_and_visited_at_and_time_read  (user_id,visited_at,time_read)
#  index_user_visits_on_visited_at_and_mobile                 (visited_at,mobile)
#
