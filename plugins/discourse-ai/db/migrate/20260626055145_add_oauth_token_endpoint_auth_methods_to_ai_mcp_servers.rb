# frozen_string_literal: true

class AddOauthTokenEndpointAuthMethodsToAiMcpServers < ActiveRecord::Migration[8.0]
  def change
    add_column :ai_mcp_servers,
               :oauth_token_endpoint_auth_methods_supported,
               :jsonb,
               null: false,
               default: []
  end
end
