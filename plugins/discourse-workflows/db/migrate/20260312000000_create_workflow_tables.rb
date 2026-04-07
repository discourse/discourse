# frozen_string_literal: true

class CreateWorkflowTables < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_workflows_workflows do |t|
      t.string :name, null: false
      t.boolean :enabled, default: false, null: false
      t.integer :allowed_group_ids, array: true, default: []
      t.jsonb :sticky_notes, default: []
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
      t.jsonb :columns, null: false, default: []
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_tables, :name, unique: true

    create_table :discourse_workflows_data_table_columns do |t|
      t.bigint :data_table_id, null: false
      t.string :name, null: false, limit: 63
      t.string :column_type, null: false, limit: 20
      t.integer :position, null: false
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_table_columns, :data_table_id
    add_index :discourse_workflows_data_table_columns, %i[data_table_id name], unique: true
    add_index :discourse_workflows_data_table_columns, %i[data_table_id position], unique: true

    create_table :discourse_workflows_data_table_rows do |t|
      t.integer :data_table_id, null: false
      t.jsonb :data, null: false, default: {}
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_table_rows, :data_table_id

    create_table :discourse_workflows_credentials do |t|
      t.string :name, limit: 128, null: false
      t.string :credential_type, limit: 64, null: false
      t.text :data, null: false
      t.timestamps
    end

    add_index :discourse_workflows_credentials, :credential_type
  end
end
