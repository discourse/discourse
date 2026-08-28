# frozen_string_literal: true

class AddWarnedToWorkflowExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_workflows_executions, :warned, :boolean, null: false, default: false
  end
end
