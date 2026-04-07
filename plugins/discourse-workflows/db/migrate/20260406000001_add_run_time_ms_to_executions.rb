# frozen_string_literal: true

class AddRunTimeMsToExecutions < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_workflows_executions, :run_time_ms, :integer
  end
end
