# frozen_string_literal: true

class AddOauthFieldsToAiMcpServers < ActiveRecord::Migration[7.2]
  def up
    change_table :ai_mcp_servers do |t|
      t.string :auth_type, null: false, limit: 50, default: "header_secret"
      t.string :oauth_client_registration, limit: 50, default: "client_metadata_document"
      t.string :oauth_client_id, limit: 1000
      t.bigint :oauth_client_secret_ai_secret_id
      t.string :oauth_scopes, limit: 2000
      t.string :oauth_granted_scopes, limit: 2000
      t.string :oauth_token_type, limit: 100
      t.datetime :oauth_access_token_expires_at
      t.string :oauth_authorization_endpoint, limit: 1000
      t.string :oauth_token_endpoint, limit: 1000
      t.string :oauth_revocation_endpoint, limit: 1000
      t.string :oauth_issuer, limit: 1000
      t.string :oauth_resource_metadata_url, limit: 1000
      t.string :oauth_status, null: false, limit: 50, default: "disconnected"
      t.string :oauth_last_error, limit: 1000
      t.datetime :oauth_last_authorized_at
      t.datetime :oauth_last_refreshed_at
    end

    add_index :ai_mcp_servers, :oauth_client_secret_ai_secret_id

    execute <<~SQL
      UPDATE ai_mcp_servers
      SET auth_type = CASE WHEN ai_secret_id IS NULL THEN 'none' ELSE 'header_secret' END
    SQL
  end

  def down
    remove_index :ai_mcp_servers, :oauth_client_secret_ai_secret_id

    change_table :ai_mcp_servers do |t|
      t.remove :auth_type
      t.remove :oauth_client_registration
      t.remove :oauth_client_id
      t.remove :oauth_client_secret_ai_secret_id
      t.remove :oauth_scopes
      t.remove :oauth_granted_scopes
      t.remove :oauth_token_type
      t.remove :oauth_access_token_expires_at
      t.remove :oauth_authorization_endpoint
      t.remove :oauth_token_endpoint
      t.remove :oauth_revocation_endpoint
      t.remove :oauth_issuer
      t.remove :oauth_resource_metadata_url
      t.remove :oauth_status
      t.remove :oauth_last_error
      t.remove :oauth_last_authorized_at
      t.remove :oauth_last_refreshed_at
    end
  end
end
