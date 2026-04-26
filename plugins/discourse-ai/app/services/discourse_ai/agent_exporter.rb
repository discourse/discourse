# frozen_string_literal: true

module DiscourseAi
  class AgentExporter
    def initialize(agent:)
      raise ArgumentError, "Invalid agent provided" if !agent.is_a?(AiAgent)
      @agent = agent
    end

    def export
      serialized_custom_tools = serialize_tools(@agent)
      serialize_agent(@agent, serialized_custom_tools)
    end

    private

    def serialize_tools(ai_agent)
      custom_tool_ids =
        (ai_agent.tools || []).filter_map do |tool_config|
          # A tool config is an array like: ["custom-ID", {options}, force_flag]
          if tool_config.is_a?(Array) && tool_config[0].to_s.start_with?("custom-")
            tool_config[0].split("-", 2).last.to_i
          end
        end

      return [] if custom_tool_ids.empty?

      tools = AiTool.where(id: custom_tool_ids)
      tools.map do |tool|
        {
          identifier: tool.tool_name, # Use tool_name for portability
          name: tool.name,
          description: tool.description,
          tool_name: tool.tool_name,
          parameters: tool.parameters,
          secret_contracts: tool.secret_contracts,
          summary: tool.summary,
          script: tool.script,
        }
      end
    end

    def serialize_agent(ai_agent, serialized_custom_tools)
      export_data = {
        meta: {
          version: "1.0",
          exported_at: Time.zone.now.iso8601,
        },
        agent: {
          name: ai_agent.name,
          description: ai_agent.description,
          system_prompt: ai_agent.system_prompt,
          examples: ai_agent.examples,
          temperature: ai_agent.temperature,
          top_p: ai_agent.top_p,
          response_format: ai_agent.response_format,
          tools: transform_tools_for_export(ai_agent.tools, serialized_custom_tools),
          mcp_servers: serialize_mcp_servers(ai_agent),
        },
        custom_tools: serialized_custom_tools,
      }

      JSON.pretty_generate(export_data)
    end

    def transform_tools_for_export(tools_config, _serialized_custom_tools)
      return [] if tools_config.blank?

      tools_config.map do |tool_config|
        unless tool_config.is_a?(Array) && tool_config[0].to_s.start_with?("custom-")
          next tool_config
        end

        tool_id = tool_config[0].split("-", 2).last.to_i
        tool = AiTool.find_by(id: tool_id)
        next tool_config unless tool

        ["custom-#{tool.tool_name}", tool_config[1], tool_config[2]]
      end
    end

    def serialize_mcp_servers(ai_agent)
      ai_agent
        .ai_agent_mcp_servers
        .includes(:ai_mcp_server)
        .sort_by { |assignment| assignment.ai_mcp_server.name.downcase }
        .map do |assignment|
          server_data = { name: assignment.ai_mcp_server.name }
          if !assignment.all_tools_enabled?
            server_data[:selected_tool_names] = assignment.selected_tool_names
          end
          server_data
        end
    end
  end
end
