# frozen_string_literal: true

class AddErrorWorkflowIdToDiscourseWorkflowsWorkflows < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_workflows_workflows, :error_workflow_id, :integer, null: true
    add_index :discourse_workflows_workflows, :error_workflow_id
  end
end
