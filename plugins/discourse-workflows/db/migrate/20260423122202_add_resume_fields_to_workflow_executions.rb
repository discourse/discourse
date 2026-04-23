# frozen_string_literal: true

class AddResumeFieldsToWorkflowExecutions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_column :discourse_workflows_executions, :resume_token, :string
    add_column :discourse_workflows_executions, :timeout_action, :string

    remove_index :discourse_workflows_executions,
                 :resume_token,
                 algorithm: :concurrently,
                 if_exists: true
    add_index :discourse_workflows_executions,
              :resume_token,
              where: "resume_token IS NOT NULL",
              algorithm: :concurrently,
              if_not_exists: true

    execute <<~SQL
      UPDATE discourse_workflows_executions
      SET resume_token = waiting_config->>'resume_token',
          timeout_action = waiting_config->>'timeout_action'
      WHERE status = 4
        AND waiting_config IS NOT NULL
        AND waiting_config != '{}'::jsonb
    SQL

    execute <<~SQL
      UPDATE discourse_workflows_execution_data ed
      SET data = jsonb_set(
        COALESCE(ed.data::jsonb, '{}'::jsonb),
        '{node_contexts}',
        COALESCE(e.waiting_config->'node_contexts', '{}'::jsonb),
        true
      )::text
      FROM discourse_workflows_executions e
      WHERE ed.execution_id = e.id
        AND e.status = 4
        AND e.waiting_config ? 'node_contexts'
    SQL
  end

  def down
    remove_index :discourse_workflows_executions, :resume_token, if_exists: true
    remove_column :discourse_workflows_executions, :resume_token
    remove_column :discourse_workflows_executions, :timeout_action
  end
end
