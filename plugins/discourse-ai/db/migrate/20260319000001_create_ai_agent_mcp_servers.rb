# frozen_string_literal: true

class CreateAiAgentMcpServers < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_agent_mcp_servers do |t|
      t.bigint :ai_agent_id, null: false
      t.bigint :ai_mcp_server_id, null: false
      t.timestamps
    end

    add_index :ai_agent_mcp_servers, %i[ai_agent_id ai_mcp_server_id], unique: true
    add_index :ai_agent_mcp_servers, :ai_mcp_server_id
  end
end
