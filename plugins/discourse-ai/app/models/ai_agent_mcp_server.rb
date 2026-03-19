# frozen_string_literal: true

class AiAgentMcpServer < ActiveRecord::Base
  belongs_to :ai_agent
  belongs_to :ai_mcp_server

  validates :ai_agent_id, presence: true
  validates :ai_mcp_server_id, presence: true
  validates :ai_mcp_server_id, uniqueness: { scope: :ai_agent_id }
end
