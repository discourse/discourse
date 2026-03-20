# frozen_string_literal: true

class AiAgentMcpServer < ActiveRecord::Base
  belongs_to :ai_agent
  belongs_to :ai_mcp_server

  before_validation :normalize_selected_tool_names

  validates :ai_agent_id, presence: true
  validates :ai_mcp_server_id, presence: true
  validates :ai_mcp_server_id, uniqueness: { scope: :ai_agent_id }

  def selected_tool_names
    Array(self[:selected_tool_names]).filter_map(&:presence).uniq
  end

  def all_tools_enabled?
    self[:selected_tool_names].blank?
  end

  def tools_for_serialization
    return @tools_for_serialization if instance_variable_defined?(:@tools_for_serialization)

    tools = ai_mcp_server&.tools_for_serialization || []
    @tools_for_serialization =
      if all_tools_enabled?
        tools
      else
        selected_names = selected_tool_names.to_set
        tools.select { |tool| selected_names.include?(tool[:name]) }
      end
  end

  def tool_count
    tools_for_serialization.length
  end

  def token_count
    tools_for_serialization.sum { |tool| tool[:token_count].to_i }
  end

  private

  def normalize_selected_tool_names
    if instance_variable_defined?(:@tools_for_serialization)
      remove_instance_variable(:@tools_for_serialization)
    end
    self[:selected_tool_names] = selected_tool_names.presence
  end
end
