# frozen_string_literal: true

class CreateAiAuthoringSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_workflows_ai_authoring_sessions do |t|
      t.bigint :workflow_id
      t.integer :user_id, null: false
      t.string :status, null: false, limit: 40, default: "drafting"
      t.jsonb :messages, null: false, default: []
      t.text :latest_request
      t.jsonb :latest_response, null: false, default: {}
      t.jsonb :proposed_patch, null: false, default: {}
      t.string :base_workflow_version_id, limit: 36
      t.string :base_graph_digest, limit: 64
      t.string :risk_level, limit: 20
      t.datetime :applied_at
      t.timestamps null: false
    end

    add_index :discourse_workflows_ai_authoring_sessions,
              :workflow_id,
              name: "idx_dwf_ai_sessions_on_workflow_id"
    add_index :discourse_workflows_ai_authoring_sessions,
              :user_id,
              name: "idx_dwf_ai_sessions_on_user_id"
    add_index :discourse_workflows_ai_authoring_sessions,
              %i[status updated_at],
              name: "idx_dwf_ai_sessions_on_status_updated_at"
  end
end
