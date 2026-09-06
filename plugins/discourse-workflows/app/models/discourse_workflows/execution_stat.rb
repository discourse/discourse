# frozen_string_literal: true

module DiscourseWorkflows
  class ExecutionStat < ActiveRecord::Base
    self.table_name = "discourse_workflows_execution_stats"

    def self.log(workflow_id, date: Date.current)
      DB.exec(<<~SQL, workflow_id: workflow_id, date: date)
        INSERT INTO discourse_workflows_execution_stats (workflow_id, date, total_runs)
        VALUES (:workflow_id, :date, 1)
        ON CONFLICT (workflow_id, date)
        DO UPDATE SET total_runs = discourse_workflows_execution_stats.total_runs + 1
      SQL
    end
  end
end

# == Schema Information
#
# Table name: discourse_workflows_execution_stats
#
#  id          :bigint           not null, primary key
#  date        :date             not null
#  total_runs  :integer          default(0), not null
#  workflow_id :bigint           not null
#
# Indexes
#
#  idx_dwf_execution_stats_on_workflow_id_and_date  (workflow_id,date) UNIQUE
#
