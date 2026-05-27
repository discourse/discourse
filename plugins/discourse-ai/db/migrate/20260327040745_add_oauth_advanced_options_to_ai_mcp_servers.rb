# frozen_string_literal: true

class AddOauthAdvancedOptionsToAiMcpServers < ActiveRecord::Migration[7.2]
  def up
    add_column :ai_mcp_servers, :oauth_authorization_params, :jsonb, null: false, default: {}
    add_column :ai_mcp_servers, :oauth_token_params, :jsonb, null: false, default: {}
    add_column :ai_mcp_servers, :oauth_require_refresh_token, :boolean, null: false, default: false
  end

  def down
    remove_column :ai_mcp_servers, :oauth_authorization_params
    remove_column :ai_mcp_servers, :oauth_token_params
    remove_column :ai_mcp_servers, :oauth_require_refresh_token
  end
end
