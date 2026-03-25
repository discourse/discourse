# frozen_string_literal: true

class CreateWorkflowTables < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_workflows_workflows do |t|
      t.string :name, null: false
      t.boolean :enabled, default: false, null: false
      t.integer :allowed_group_ids, array: true, default: []
      t.jsonb :sticky_notes, default: []
      t.integer :created_by_id, null: false
      t.integer :updated_by_id
      t.timestamps null: false
    end

    add_index :discourse_workflows_workflows, :created_by_id
    add_index :discourse_workflows_workflows, :updated_by_id

    create_table :discourse_workflows_nodes do |t|
      t.integer :workflow_id, null: false
      t.string :type, null: false
      t.string :type_version, null: false, default: "1.0"
      t.string :name, null: false
      t.jsonb :position, default: [0, 0]
      t.integer :position_index, null: false, default: 0
      t.jsonb :configuration, default: {}
      t.jsonb :static_data, default: {}, null: false
      t.timestamps null: false
    end

    add_index :discourse_workflows_nodes, :workflow_id

    create_table :discourse_workflows_connections do |t|
      t.integer :workflow_id, null: false
      t.integer :source_node_id, null: false
      t.string :source_output, null: false, default: "main"
      t.integer :target_node_id, null: false
      t.string :target_input, null: false, default: "main"
      t.timestamps null: false
    end

    add_index :discourse_workflows_connections, :workflow_id
    add_index :discourse_workflows_connections, :source_node_id
    add_index :discourse_workflows_connections, :target_node_id

    create_table :discourse_workflows_executions do |t|
      t.integer :workflow_id, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :trigger_data, default: {}
      t.jsonb :context, default: {}
      t.text :error
      t.integer :waiting_node_id
      t.datetime :waiting_until
      t.jsonb :waiting_config, default: {}, null: false
      t.jsonb :workflow_data, default: {}, null: false
      t.integer :trigger_node_id
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

    create_table :discourse_workflows_execution_steps do |t|
      t.integer :execution_id, null: false
      t.integer :node_id, null: false
      t.string :node_name
      t.string :node_type
      t.integer :position, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.jsonb :input, default: {}
      t.jsonb :output, default: {}
      t.jsonb :metadata, default: {}
      t.text :error
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps null: false
    end

    add_index :discourse_workflows_execution_steps, :execution_id
    add_index :discourse_workflows_execution_steps, :node_id

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

    create_table :discourse_workflows_data_table_rows do |t|
      t.integer :data_table_id, null: false
      t.jsonb :data, null: false, default: {}
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_table_rows, :data_table_id
  end
end
