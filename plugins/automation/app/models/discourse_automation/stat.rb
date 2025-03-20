# frozen_string_literal: true
#
module DiscourseAutomation
  class Stat < ActiveRecord::Base
    self.table_name = "discourse_automation_stats"

    def self.log(automation_id, run_time = nil)
      if block_given? && run_time.nil?
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        run_time = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        result
      end
    ensure
      update_stats(automation_id, run_time)
    end

    def self.update_stats(automation_id, run_time)
      today = Date.current
      current_time = Time.now

      builder = DB.build <<~SQL
        INSERT INTO discourse_automation_stats
        (automation_id, date, last_run_at, total_time, average_run_time, min_run_time, max_run_time, total_runs)
        VALUES (:automation_id, :date, :current_time, :run_time, :run_time, :run_time, :run_time, 1)
        ON CONFLICT (automation_id, date) DO UPDATE SET
          last_run_at = :current_time,
          total_time = discourse_automation_stats.total_time + :run_time,
          total_runs = discourse_automation_stats.total_runs + 1,
          average_run_time = (discourse_automation_stats.total_time + :run_time) / (discourse_automation_stats.total_runs + 1),
          min_run_time = LEAST(discourse_automation_stats.min_run_time, :run_time),
          max_run_time = GREATEST(discourse_automation_stats.max_run_time, :run_time)
      SQL

      builder.exec(
        automation_id: automation_id,
        date: today,
        current_time: current_time,
        run_time: run_time,
      )
    end
  end
end

# == Schema Information
#
# Table name: discourse_automation_stats
#
#  id               :bigint           not null, primary key
#  automation_id    :bigint           not null
#  date             :date             not null
#  last_run_at      :datetime         not null
#  total_time       :float            not null
#  average_run_time :float            not null
#  min_run_time     :float            not null
#  max_run_time     :float            not null
#  total_runs       :integer          not null
#
# Indexes
#
#  index_discourse_automation_stats_on_automation_id_and_date  (automation_id,date) UNIQUE
#
