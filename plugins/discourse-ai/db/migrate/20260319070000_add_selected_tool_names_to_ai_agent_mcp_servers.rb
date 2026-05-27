# frozen_string_literal: true

class AddSelectedToolNamesToAiAgentMcpServers < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_agent_mcp_servers, :selected_tool_names, :jsonb
  end
end
