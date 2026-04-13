# frozen_string_literal: true

class CreateWorkflowTables < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_workflows_workflows do |t|
      t.string :name, null: false
      t.boolean :enabled, default: false, null: false
      t.jsonb :nodes, default: []
      t.jsonb :connections, default: []
      t.jsonb :static_data, default: {}
      t.jsonb :settings
      t.integer :error_workflow_id
      t.string :run_as_username, default: "system"
      t.integer :created_by_id, null: false
      t.integer :updated_by_id
      t.timestamps null: false
    end

    add_index :discourse_workflows_workflows, :created_by_id
    add_index :discourse_workflows_workflows, :updated_by_id
    add_index :discourse_workflows_workflows, :error_workflow_id
    add_index :discourse_workflows_workflows, :nodes, using: :gin, name: "idx_workflows_nodes_gin"

    create_table :discourse_workflows_executions do |t|
      t.integer :workflow_id, null: false
      t.integer :status, null: false, default: 0
      t.integer :execution_mode, default: 0, null: false
      t.jsonb :trigger_data, default: {}
      t.text :error
      t.string :waiting_node_id
      t.datetime :waiting_until
      t.jsonb :waiting_config, default: {}, null: false
      t.string :trigger_node_id
      t.integer :run_time_ms
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps null: false
    end

    add_index :discourse_workflows_executions, :workflow_id
    add_index :discourse_workflows_executions, :status
    add_index :discourse_workflows_executions, :waiting_node_id
    add_index :discourse_workflows_executions,
              :waiting_until,
              where: "waiting_until IS NOT NULL AND status = 4",
              name: "idx_executions_waiting_until"
    add_index :discourse_workflows_executions,
              %i[workflow_id created_at id],
              name: "idx_dwf_executions_workflow_created_at_id_desc",
              order: {
                created_at: :desc,
                id: :desc,
              }

    create_table :discourse_workflows_execution_data, id: false do |t|
      t.bigint :execution_id, null: false, primary_key: true
      t.text :data
      t.jsonb :workflow_data, default: {}, null: false
    end

    add_foreign_key :discourse_workflows_execution_data,
                    :discourse_workflows_executions,
                    column: :execution_id,
                    on_delete: :cascade

    create_table :discourse_workflows_variables do |t|
      t.string :key, null: false, limit: 100
      t.string :value, null: false, default: "", limit: 1000
      t.text :description
      t.timestamps
    end

    add_index :discourse_workflows_variables, :key, unique: true

    create_table :discourse_workflows_data_tables do |t|
      t.string :name, null: false, limit: 100
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_tables, :name, unique: true

    create_table :discourse_workflows_credentials do |t|
      t.string :name, limit: 128, null: false
      t.string :credential_type, limit: 64, null: false
      t.text :data, null: false
      t.timestamps
    end

    add_index :discourse_workflows_credentials, :credential_type

    create_table :discourse_workflows_workflow_dependencies do |t|
      t.integer :workflow_id, null: false
      t.string :dependency_type, null: false, limit: 50
      t.string :dependency_key, null: false, limit: 500
      t.string :node_id, limit: 100
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :discourse_workflows_workflow_dependencies, :workflow_id
    add_index :discourse_workflows_workflow_dependencies,
              %i[dependency_type dependency_key],
              name: "idx_workflow_deps_type_key"
    add_foreign_key :discourse_workflows_workflow_dependencies,
                    :discourse_workflows_workflows,
                    column: :workflow_id,
                    on_delete: :cascade
  end
end
