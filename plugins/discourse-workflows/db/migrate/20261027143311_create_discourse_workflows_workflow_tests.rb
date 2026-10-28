# frozen_string_literal: true

class CreateDiscourseWorkflowsWorkflowTests < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_workflow_tests do |table|
      table.bigint :workflow_id, null: false
      table.string :name, limit: 100, null: false
      table.string :trigger_node_id, null: false
      table.string :trigger_type, null: false
      table.integer :trigger_type_version, null: false, default: 1
      table.jsonb :trigger_data, null: false, default: {}
      table.bigint :source_execution_id, null: false
      table.jsonb :captured_outputs, null: false, default: {}
      table.datetime :captured_at
      table.jsonb :pasted_responses, null: false, default: {}
      table.jsonb :checks, null: false, default: []
      table.string :definition_digest, limit: 64, null: false
      table.bigint :latest_execution_id
      table.bigint :created_by_id, null: false
      table.bigint :updated_by_id, null: false
      table.timestamps
    end

    add_index :discourse_workflows_workflow_tests,
              %i[workflow_id created_at],
              name: "idx_dwf_workflow_tests_on_workflow_created_at"
  end
end
