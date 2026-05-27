# frozen_string_literal: true
#
module DiscourseAutomation
  class Stat < ActiveRecord::Base
    self.table_name = "discourse_automation_stats"

    def self.log(automation_id, run_time = nil)
      errored = false
      if block_given? && run_time.nil?
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          result = yield
          run_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          result
        rescue => e
          run_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          errored = true
          raise e
        end
      end
    ensure
      update_stats(automation_id, run_time || 0, errored:)
    end

    def self.fetch_period_summaries
      today = Date.current

      # Define our time periods
      periods = {
        last_day: {
          start_date: today - 1.day,
          end_date: today,
        },
        last_week: {
          start_date: today - 1.week,
          end_date: today,
        },
        last_month: {
          start_date: today - 1.month,
          end_date: today,
        },
      }

      result = {}

      periods.each do |period_name, date_range|
        builder = DB.build <<~SQL
          SELECT
            automation_id,
            SUM(total_runs) AS total_runs,
            SUM(total_time) AS total_time,
            SUM(total_errors) AS total_errors,
            CASE WHEN SUM(total_runs) > 0
              THEN SUM(total_time) / SUM(total_runs)
              ELSE 0
            END AS average_run_time,
            MIN(min_run_time) AS min_run_time,
            MAX(max_run_time) AS max_run_time
          FROM discourse_automation_stats
          WHERE date >= :start_date AND date <= :end_date
          GROUP BY automation_id
        SQL

        stats = builder.query(start_date: date_range[:start_date], end_date: date_range[:end_date])

        last_run_stats = DB.query_array <<~SQL
          SELECT
            automation_id,
            MAX(last_run_at) AS last_run_at
          FROM discourse_automation_stats
          GROUP BY automation_id
        SQL
        last_run_stats = Hash[*last_run_stats.flatten]

        stats.each do |stat|
          automation_id = stat.automation_id
          result[automation_id] ||= {}
          result[automation_id][:last_run_at] = last_run_stats[automation_id]
          result[automation_id][period_name] = {
            total_runs: stat.total_runs,
            total_time: stat.total_time,
            total_errors: stat.total_errors,
            average_run_time: stat.average_run_time,
            min_run_time: stat.min_run_time,
            max_run_time: stat.max_run_time,
          }
        end
      end

      result
    end

    def self.update_stats(automation_id, run_time, errored: false)
      today = Date.current
      current_time = Time.now
      error_increment = errored ? 1 : 0

      builder = DB.build <<~SQL
        INSERT INTO discourse_automation_stats
        (automation_id, date, last_run_at, total_time, average_run_time, min_run_time, max_run_time, total_runs, total_errors)
        VALUES (:automation_id, :date, :current_time, :run_time, :run_time, :run_time, :run_time, 1, :error_increment)
        ON CONFLICT (automation_id, date) DO UPDATE SET
          last_run_at = :current_time,
          total_time = discourse_automation_stats.total_time + :run_time,
          total_runs = discourse_automation_stats.total_runs + 1,
          total_errors = discourse_automation_stats.total_errors + :error_increment,
          average_run_time = (discourse_automation_stats.total_time + :run_time) / (discourse_automation_stats.total_runs + 1),
          min_run_time = LEAST(discourse_automation_stats.min_run_time, :run_time),
          max_run_time = GREATEST(discourse_automation_stats.max_run_time, :run_time)
      SQL

      builder.exec(automation_id:, date: today, current_time:, run_time:, error_increment:)
    end
  end
end

# == Schema Information
#
# Table name: discourse_automation_stats
#
#  id               :bigint           not null, primary key
#  average_run_time :float            not null
#  date             :date             not null
#  last_run_at      :datetime         not null
#  max_run_time     :float            not null
#  min_run_time     :float            not null
#  total_errors     :integer          default(0), not null
#  total_runs       :integer          not null
#  total_time       :float            not null
#  automation_id    :bigint           not null
#
# Indexes
#
#  index_discourse_automation_stats_on_automation_id_and_date  (automation_id,date) UNIQUE
#
