# frozen_string_literal: true

class AddUniqueIndexToWorkflowExecutionJobId < ActiveRecord::Migration[8.0]
  INDEX_NAME = "idx_dwf_executions_on_job_id"

  disable_ddl_transaction!

  def up
    remove_index :discourse_workflows_executions,
                 name: INDEX_NAME,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :discourse_workflows_executions,
              :job_id,
              unique: true,
              where: "job_id IS NOT NULL",
              name: INDEX_NAME,
              algorithm: :concurrently
  end

  def down
    remove_index :discourse_workflows_executions, name: INDEX_NAME, algorithm: :concurrently
  end
end
