# frozen_string_literal: true

class CreateAiMcpServers < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_mcp_servers do |t|
      t.string :name, null: false, limit: 100
      t.string :description, null: false, limit: 1000
      t.string :url, null: false, limit: 1000
      t.bigint :ai_secret_id
      t.string :auth_header, null: false, limit: 100, default: "Authorization"
      t.string :auth_scheme, null: false, limit: 100, default: "Bearer"
      t.boolean :enabled, null: false, default: true
      t.integer :timeout_seconds, null: false, default: 30
      t.string :last_health_status, limit: 50
      t.string :last_health_error, limit: 1000
      t.datetime :last_checked_at
      t.datetime :last_tools_synced_at
      t.jsonb :server_capabilities, null: false, default: {}
      t.string :protocol_version, limit: 100
      t.integer :created_by_id
      t.timestamps
    end

    add_index :ai_mcp_servers, :name, unique: true
    add_index :ai_mcp_servers, :ai_secret_id
  end
end
