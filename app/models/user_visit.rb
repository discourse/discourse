# frozen_string_literal: true

class UserVisit < ActiveRecord::Base
  def self.counts_by_day_query(start_date, end_date, group_id = nil)
    result = where('visited_at >= ? and visited_at <= ?', start_date.to_date, end_date.to_date)

    if group_id
      result = result.joins("INNER JOIN users ON users.id = user_visits.user_id")
      result = result.joins("INNER JOIN group_users ON group_users.user_id = users.id")
      result = result.where("group_users.group_id = ?", group_id)
    end
    result.group(:visited_at).order(:visited_at)
  end

  def self.count_by_active_users(start_date, end_date)
    sql = <<~SQL
      WITH dau AS (
        SELECT date_trunc('day', user_visits.visited_at)::DATE AS date,
               count(distinct user_visits.user_id) AS dau
        FROM user_visits
        WHERE user_visits.visited_at::DATE >= :start_date::DATE AND user_visits.visited_at <= :end_date::DATE
        GROUP BY date_trunc('day', user_visits.visited_at)::DATE
        ORDER BY date_trunc('day', user_visits.visited_at)::DATE
      )

      SELECT date, dau,
        (SELECT count(distinct user_visits.user_id)
          FROM user_visits
          WHERE user_visits.visited_at::DATE BETWEEN dau.date - 29 AND dau.date
        ) AS mau
      FROM dau
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
#  user_id    :integer          not null
#  visited_at :date             not null
#  posts_read :integer          default(0)
#  mobile     :boolean          default(FALSE)
#  time_read  :integer          default(0), not null
#
# Indexes
#
#  index_user_visits_on_user_id_and_visited_at                (user_id,visited_at) UNIQUE
#  index_user_visits_on_user_id_and_visited_at_and_time_read  (user_id,visited_at,time_read)
#  index_user_visits_on_visited_at_and_mobile                 (visited_at,mobile)
#
