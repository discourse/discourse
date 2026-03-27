# frozen_string_literal: true

class AddExecutionModeToDiscourseWorkflowsExecutions < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_workflows_executions, :execution_mode, :integer, default: 0, null: false
  end
end
