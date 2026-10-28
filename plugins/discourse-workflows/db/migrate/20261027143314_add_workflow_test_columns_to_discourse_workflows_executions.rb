# frozen_string_literal: true

class AddWorkflowTestColumnsToDiscourseWorkflowsExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_workflows_executions, :workflow_test_id, :bigint
    add_column :discourse_workflows_executions, :workflow_test_digest, :string, limit: 64
    add_column :discourse_workflows_executions, :pin_data_digest, :string, limit: 64
  end
end
