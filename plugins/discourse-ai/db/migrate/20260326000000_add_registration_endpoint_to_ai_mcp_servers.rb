# frozen_string_literal: true

class AddRegistrationEndpointToAiMcpServers < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_mcp_servers, :oauth_registration_endpoint, :string, limit: 1000
  end
end
