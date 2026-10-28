# frozen_string_literal: true

class AddWorkflowTestIndexToDiscourseWorkflowsExecutions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :discourse_workflows_executions,
                 %i[workflow_test_id created_at],
                 name: "idx_dwf_executions_on_workflow_test_created_at",
                 algorithm: :concurrently,
                 if_exists: true
    add_index :discourse_workflows_executions,
              %i[workflow_test_id created_at],
              name: "idx_dwf_executions_on_workflow_test_created_at",
              algorithm: :concurrently,
              where: "workflow_test_id IS NOT NULL"
  end
end
