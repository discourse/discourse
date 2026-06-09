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
      WITH visits AS (
        SELECT user_id, visited_at::DATE AS d
        FROM user_visits
        WHERE visited_at::DATE >= :start_date::DATE - 29 AND visited_at::DATE <= :end_date::DATE
      ),
      marked AS (
        SELECT user_id, d,
          CASE
            WHEN lag(d) OVER (PARTITION BY user_id ORDER BY d) >= d - 30 THEN 0
            ELSE 1
          END AS new_island
        FROM visits
      ),
      islands AS (
        SELECT user_id, d, sum(new_island) OVER (PARTITION BY user_id ORDER BY d) AS grp
        FROM marked
      ),
      coverage AS (
        SELECT min(d) AS start_d, max(d) + 29 AS end_d
        FROM islands
        GROUP BY user_id, grp
      ),
      events AS (
        SELECT start_d AS day, 1 AS delta FROM coverage
        UNION ALL
        SELECT end_d + 1 AS day, -1 AS delta FROM coverage
      ),
      running AS (
        SELECT day, sum(sum(delta)) OVER (ORDER BY day) AS mau
        FROM events
        GROUP BY day
      ),
      dau AS (
        SELECT visited_at::DATE AS date, count(distinct user_id) AS dau
        FROM user_visits
        WHERE visited_at::DATE >= :start_date::DATE AND visited_at <= :end_date::DATE
        GROUP BY visited_at::DATE
      )
      SELECT dau.date, dau.dau,
        (SELECT mau FROM running WHERE running.day <= dau.date ORDER BY day DESC LIMIT 1) AS mau
      FROM dau
      ORDER BY date
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
