# frozen_string_literal: true

class CreateWorkflowCallRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_workflow_call_runs do |t|
      t.bigint :parent_execution_id, null: false
      t.string :parent_node_id, null: false, limit: 100
      t.string :parent_resume_token, null: false, limit: 64
      t.bigint :child_execution_id
      t.bigint :target_workflow_id, null: false
      t.string :target_workflow_version_id, null: false, limit: 36
      t.bigint :user_id
      t.jsonb :trigger_data, default: {}, null: false
      t.integer :status, null: false, default: 0
      t.text :error
      t.timestamps null: false
    end

    add_index :discourse_workflows_workflow_call_runs,
              :child_execution_id,
              unique: true,
              where: "child_execution_id IS NOT NULL",
              name: "idx_dwf_call_runs_on_child_execution_id"
    add_index :discourse_workflows_workflow_call_runs,
              :parent_execution_id,
              name: "idx_dwf_call_runs_on_parent_execution_id"
  end
end
