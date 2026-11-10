# frozen_string_literal: true

class AddJobIdToWorkflowExecutions < ActiveRecord::Migration[8.0]
  def change
    add_column :discourse_workflows_executions, :job_id, :string
  end
end
