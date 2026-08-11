# frozen_string_literal: true

class CreateMcpServerTables < ActiveRecord::Migration[8.0]
  def change
    create_table :mcp_server_profiles do |table|
      table.string :name, null: false
      table.string :slug, null: false
      table.boolean :enabled, null: false, default: false
      table.text :instructions
      table.integer :allowed_group_ids, array: true, null: false, default: []
      table.string :allowed_scopes, array: true, null: false, default: []
      table.integer :catalog_revision, null: false, default: 1
      table.integer :consent_revision, null: false, default: 1
      table.integer :cache_ttl_ms, null: false, default: 300_000
      table.timestamps
    end
    add_index :mcp_server_profiles, :slug, unique: true

    create_table :mcp_server_profile_capabilities do |table|
      table.bigint :mcp_server_profile_id, null: false
      table.string :kind, null: false
      table.string :identifier, null: false
      table.boolean :enabled, null: false, default: false
      table.boolean :emergency_blocked, null: false, default: false
      table.timestamps
    end
    add_index :mcp_server_profile_capabilities,
              %i[mcp_server_profile_id kind identifier],
              unique: true,
              name: "idx_mcp_profile_capabilities_unique"

    create_table :mcp_oauth_clients do |table|
      table.string :client_id, null: false
      table.string :name, null: false
      table.string :registration_type, null: false
      table.string :trust_state, null: false, default: "approved"
      table.string :metadata_uri
      table.string :metadata_hash
      table.datetime :metadata_expires_at
      table.jsonb :metadata, null: false, default: {}
      table.string :redirect_uris, array: true, null: false, default: []
      table.datetime :last_seen_at
      table.timestamps
    end
    add_index :mcp_oauth_clients, :client_id, unique: true

    create_table :mcp_oauth_authorizations do |table|
      table.integer :user_id, null: false
      table.bigint :mcp_oauth_client_id, null: false
      table.bigint :mcp_server_profile_id, null: false
      table.string :resource, null: false
      table.string :status, null: false, default: "active"
      table.string :client_metadata_hash
      table.integer :consent_revision, null: false, default: 1
      table.integer :grant_version, null: false, default: 1
      table.datetime :consented_at, null: false
      table.datetime :revoked_at
      table.string :revoked_reason
      table.integer :revoked_by_user_id
      table.timestamps
    end
    add_index :mcp_oauth_authorizations,
              %i[user_id mcp_oauth_client_id mcp_server_profile_id],
              unique: true,
              where: "revoked_at IS NULL",
              name: "idx_mcp_active_authorizations_unique"
    add_index :mcp_oauth_authorizations, :mcp_oauth_client_id
    add_index :mcp_oauth_authorizations, :mcp_server_profile_id

    create_table :mcp_oauth_authorization_scopes do |table|
      table.bigint :mcp_oauth_authorization_id, null: false
      table.string :name, null: false
      table.timestamps
    end
    add_index :mcp_oauth_authorization_scopes,
              %i[mcp_oauth_authorization_id name],
              unique: true,
              name: "idx_mcp_authorization_scopes_unique"

    create_table :mcp_oauth_authorization_codes do |table|
      table.string :code_hash, null: false
      table.bigint :mcp_oauth_authorization_id, null: false
      table.string :redirect_uri, null: false
      table.string :resource, null: false
      table.string :code_challenge, null: false
      table.string :code_challenge_method, null: false, default: "S256"
      table.string :scopes, array: true, null: false, default: []
      table.integer :grant_version, null: false
      table.datetime :expires_at, null: false
      table.datetime :consumed_at
      table.timestamps
    end
    add_index :mcp_oauth_authorization_codes, :code_hash, unique: true
    add_index :mcp_oauth_authorization_codes, :mcp_oauth_authorization_id

    create_table :mcp_oauth_access_tokens do |table|
      table.string :token_hash, null: false
      table.bigint :mcp_oauth_authorization_id, null: false
      table.bigint :mcp_oauth_client_id, null: false
      table.bigint :mcp_server_profile_id, null: false
      table.integer :user_id, null: false
      table.string :resource, null: false
      table.string :scopes, array: true, null: false, default: []
      table.integer :grant_version, null: false
      table.datetime :expires_at, null: false
      table.datetime :last_used_at
      table.datetime :revoked_at
      table.timestamps
    end
    add_index :mcp_oauth_access_tokens, :token_hash, unique: true
    add_index :mcp_oauth_access_tokens, :mcp_oauth_authorization_id
    add_index :mcp_oauth_access_tokens, %i[user_id revoked_at]

    create_table :mcp_oauth_refresh_tokens do |table|
      table.string :token_hash, null: false
      table.string :family_id, null: false
      table.bigint :mcp_oauth_authorization_id, null: false
      table.bigint :parent_id
      table.bigint :replacement_id
      table.string :scopes, array: true, null: false, default: []
      table.integer :grant_version, null: false
      table.datetime :expires_at, null: false
      table.datetime :consumed_at
      table.datetime :revoked_at
      table.timestamps
    end
    add_index :mcp_oauth_refresh_tokens, :token_hash, unique: true
    add_index :mcp_oauth_refresh_tokens, :family_id
    add_index :mcp_oauth_refresh_tokens, :mcp_oauth_authorization_id

    create_table :mcp_audit_logs do |table|
      table.datetime :occurred_at, null: false
      table.datetime :bucket_at
      table.integer :occurrences, null: false, default: 1
      table.integer :user_id
      table.bigint :mcp_oauth_client_id
      table.bigint :mcp_server_profile_id
      table.string :request_id
      table.string :method
      table.string :capability
      table.string :outcome, null: false
      table.integer :http_status
      table.integer :duration_ms
      table.jsonb :target, null: false, default: {}
      table.timestamps
    end
    add_index :mcp_audit_logs, %i[occurred_at id]
    add_index :mcp_audit_logs, %i[mcp_server_profile_id occurred_at]
  end
end
