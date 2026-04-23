# frozen_string_literal: true

class DropWaitingConfigFromWorkflowExecutions < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:discourse_workflows_executions, :waiting_config)
      remove_column :discourse_workflows_executions, :waiting_config
    end
  end

  def down
    unless column_exists?(:discourse_workflows_executions, :waiting_config)
      add_column :discourse_workflows_executions, :waiting_config, :jsonb, default: {}, null: false
    end
  end
end
