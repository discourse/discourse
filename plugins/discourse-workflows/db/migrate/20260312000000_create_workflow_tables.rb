# frozen_string_literal: true

class CreateWorkflowTables < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_workflows do |t|
      t.string :name, null: false, limit: 100
      t.jsonb :nodes, null: false, default: []
      t.jsonb :connections, null: false, default: {}
      t.jsonb :static_data, null: false, default: {}
      t.jsonb :pin_data, null: false, default: {}
      t.jsonb :trigger_state, null: false, default: {}
      t.jsonb :settings, null: false, default: {}
      t.string :version_id, null: false, limit: 36
      t.string :active_version_id, limit: 36
      t.integer :version_counter, null: false, default: 1
      t.bigint :error_workflow_id
      t.integer :created_by_id, null: false
      t.integer :updated_by_id
      t.timestamps null: false
    end

    add_index :discourse_workflows_workflows,
              :created_by_id,
              name: "idx_dwf_workflows_on_created_by_id"
    add_index :discourse_workflows_workflows,
              :updated_by_id,
              name: "idx_dwf_workflows_on_updated_by_id"
    add_index :discourse_workflows_workflows,
              :error_workflow_id,
              name: "idx_dwf_workflows_on_error_workflow_id"
    add_index :discourse_workflows_workflows,
              :version_id,
              unique: true,
              name: "idx_dwf_workflows_on_version_id"
    add_index :discourse_workflows_workflows,
              :active_version_id,
              name: "idx_dwf_workflows_on_active_version_id"

    create_table :discourse_workflows_workflow_versions, id: false do |t|
      t.string :version_id, null: false, limit: 36, primary_key: true
      t.bigint :workflow_id, null: false
      t.integer :version_number, null: false
      t.string :name, null: false, limit: 100
      t.jsonb :nodes, null: false, default: []
      t.jsonb :connections, null: false, default: {}
      t.jsonb :settings, null: false, default: {}
      t.boolean :autosaved, null: false, default: false
      t.text :authors
      t.integer :created_by_id, null: false
      t.integer :updated_by_id
      t.timestamps null: false
    end

    add_index :discourse_workflows_workflow_versions,
              :workflow_id,
              name: "idx_dwf_versions_on_workflow_id"
    add_index :discourse_workflows_workflow_versions,
              %i[workflow_id version_number],
              unique: true,
              name: "idx_dwf_versions_on_workflow_version_number"
    add_index :discourse_workflows_workflow_versions,
              %i[workflow_id created_at],
              order: {
                created_at: :desc,
              },
              name: "idx_dwf_versions_on_workflow_created_at"

    create_table :discourse_workflows_workflow_publish_history do |t|
      t.bigint :workflow_id, null: false
      t.string :version_id, limit: 36
      t.string :event, null: false, limit: 32
      t.integer :user_id
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :discourse_workflows_workflow_publish_history,
              %i[workflow_id created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              name: "idx_dwf_publish_history_on_workflow_created_at_id_desc"

    create_table :discourse_workflows_executions do |t|
      t.bigint :workflow_id, null: false
      t.string :workflow_version_id, null: false, limit: 36
      t.integer :status, null: false, default: 0
      t.integer :execution_mode, default: 0, null: false
      t.jsonb :trigger_data, default: {}
      t.text :error
      t.string :waiting_node_id, limit: 100
      t.datetime :waiting_until
      t.string :resume_token, limit: 64
      t.string :timeout_action, limit: 32
      t.string :trigger_node_id, limit: 100
      t.integer :run_time_ms
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps null: false
    end

    add_index :discourse_workflows_executions,
              :resume_token,
              where: "resume_token IS NOT NULL",
              name: "idx_dwf_executions_on_resume_token"
    add_index :discourse_workflows_executions,
              :waiting_until,
              where: "waiting_until IS NOT NULL AND status = 4",
              name: "idx_dwf_executions_on_waiting_until"
    add_index :discourse_workflows_executions,
              %i[status waiting_until],
              name: "idx_dwf_executions_on_status_waiting_until"
    add_index :discourse_workflows_executions,
              %i[workflow_id created_at id],
              order: {
                created_at: :desc,
                id: :desc,
              },
              name: "idx_dwf_executions_on_workflow_created_at_id_desc"
    add_index :discourse_workflows_executions,
              :workflow_version_id,
              name: "idx_dwf_executions_on_workflow_version_id"
    add_index :discourse_workflows_executions,
              :created_at,
              where: "status IN (2, 3, 5, 6)",
              name: "idx_dwf_executions_on_retention"

    create_table :discourse_workflows_execution_data, id: false do |t|
      t.bigint :execution_id, null: false
      t.jsonb :data, default: {}, null: false
      t.jsonb :workflow_data, default: {}, null: false
    end

    add_index :discourse_workflows_execution_data,
              :execution_id,
              unique: true,
              name: "idx_dwf_execution_data_on_execution_id"

    create_table :discourse_workflows_variables do |t|
      t.string :key, null: false, limit: 100
      t.string :value, null: false, default: "", limit: 1000
      t.text :description
      t.integer :created_by_id, null: false
      t.timestamps
    end

    add_index :discourse_workflows_variables, :key, unique: true, name: "idx_dwf_variables_on_key"
    add_index :discourse_workflows_variables,
              :created_by_id,
              name: "idx_dwf_variables_on_created_by_id"

    create_table :discourse_workflows_data_tables do |t|
      t.string :name, null: false, limit: 100
      t.integer :created_by_id
      t.integer :updated_by_id
      t.timestamps null: false
    end

    add_index :discourse_workflows_data_tables,
              :name,
              unique: true,
              name: "idx_dwf_data_tables_on_name"
    add_index :discourse_workflows_data_tables,
              :created_by_id,
              name: "idx_dwf_data_tables_on_created_by_id"
    add_index :discourse_workflows_data_tables,
              :updated_by_id,
              name: "idx_dwf_data_tables_on_updated_by_id"

    create_table :discourse_workflows_credentials do |t|
      t.string :name, limit: 128, null: false
      t.string :credential_type, limit: 64, null: false
      t.jsonb :data, null: false, default: {}
      t.integer :created_by_id
      t.integer :updated_by_id
      t.timestamps
    end

    add_index :discourse_workflows_credentials,
              :credential_type,
              name: "idx_dwf_credentials_on_credential_type"
    add_index :discourse_workflows_credentials,
              :created_by_id,
              name: "idx_dwf_credentials_on_created_by_id"
    add_index :discourse_workflows_credentials,
              :updated_by_id,
              name: "idx_dwf_credentials_on_updated_by_id"
    add_index :discourse_workflows_credentials,
              %i[name credential_type],
              unique: true,
              name: "idx_dwf_credentials_on_name_credential_type"

    create_table :discourse_workflows_workflow_dependencies do |t|
      t.bigint :workflow_id, null: false
      t.string :dependency_type, null: false, limit: 50
      t.string :dependency_key, null: false, limit: 500
      t.string :node_id, limit: 100
      t.string :workflow_version_id, limit: 36
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :discourse_workflows_workflow_dependencies,
              :workflow_id,
              name: "idx_dwf_deps_on_workflow_id"
    add_index :discourse_workflows_workflow_dependencies,
              %i[dependency_type dependency_key],
              name: "idx_dwf_deps_on_type_key"
    add_index :discourse_workflows_workflow_dependencies,
              :workflow_version_id,
              name: "idx_dwf_deps_on_workflow_version_id"

    create_table :discourse_workflows_webhooks do |t|
      t.bigint :workflow_id, null: false
      t.string :workflow_version_id, limit: 36
      t.string :node_name, null: false, limit: 100
      t.string :webhook_path, null: false, limit: 500
      t.string :http_method, null: false, limit: 10
      t.string :webhook_id, limit: 36
      t.integer :path_length
      t.boolean :test_webhook, null: false, default: false
      t.integer :user_id
      t.jsonb :workflow_snapshot
      t.datetime :expires_at
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :discourse_workflows_webhooks,
              %i[http_method webhook_path test_webhook],
              unique: true,
              name: "idx_dwf_webhooks_on_method_path_test"
    add_index :discourse_workflows_webhooks,
              %i[webhook_id http_method test_webhook],
              name: "idx_dwf_webhooks_on_webhook_id_method_test",
              where: "webhook_id IS NOT NULL"
    add_index :discourse_workflows_webhooks, :workflow_id, name: "idx_dwf_webhooks_on_workflow_id"
    add_index :discourse_workflows_webhooks,
              :workflow_version_id,
              name: "idx_dwf_webhooks_on_workflow_version_id"
    add_index :discourse_workflows_webhooks,
              :expires_at,
              name: "idx_dwf_webhooks_on_expires_at",
              where: "expires_at IS NOT NULL"
  end
end
