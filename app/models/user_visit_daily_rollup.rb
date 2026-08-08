# frozen_string_literal: true

class UserVisitDailyRollup < ActiveRecord::Base
  def self.fetch(start_date:, end_date:)
    where(date: start_date.to_date..end_date.to_date)
      .order(:date)
      .pluck(:date, :dau, :mau)
      .map { |date, dau, mau| { "date" => date, "dau" => dau, "mau" => mau } }
  end

  def self.aggregate(start_date:, end_date:)
    rows = UserVisit.count_by_active_users(start_date, end_date)

    transaction { replace!(start_date: start_date, end_date: end_date, rows: rows) }
    nil
  end

  def self.replace!(start_date:, end_date:, rows:)
    start_date = start_date.to_date
    end_date = end_date.to_date
    where(date: start_date..end_date).delete_all
    return if rows.empty?

    insert_all!(
      rows.map { |row| { date: row.fetch("date"), dau: row.fetch("dau"), mau: row.fetch("mau") } },
    )
  end
  private_class_method :replace!
end

# == Schema Information
#
# Table name: user_visit_daily_rollups
#
#  id   :bigint           not null, primary key
#  date :date             not null
#  dau  :bigint           not null
#  mau  :bigint           not null
#
# Indexes
#
#  index_user_visit_daily_rollups_on_date  (date) UNIQUE
#
