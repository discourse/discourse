# frozen_string_literal: true

module DiscourseAi
  module Mcp
    class WorkflowTool
      def self.servers
        AiMcpServer.where(enabled: true).order(:name).select { |server| available?(server) }
      end

      def self.available?(server)
        server && (!server.oauth? || server.oauth_connected?) &&
          (!server.header_secret? || server.ai_secret_id.present?)
      end

      def self.find(server_id, tool_name)
        tools(server_id).find { |tool| tool.name == tool_name }
      end

      def self.tools(server_id)
        return [] if !server_id.to_s.match?(/\A[1-9][0-9]*\z/)

        server = AiMcpServer.find_by(id: server_id, enabled: true)
        return [] if !available?(server)

        server.tool_definitions.filter_map do |definition|
          next if !definition.is_a?(Hash)

          name = definition["name"].presence
          schema = definition["inputSchema"]
          next if !name.is_a?(String) || !schema.is_a?(Hash)

          new(Agents::Tools::Mcp.class_instance(server.id, name, definition))
        end
      end

      def initialize(tool_class)
        @tool_class = tool_class
      end

      def name
        @tool_class.tool_name
      end

      def title
        value = @tool_class.placeholder_summary
        value.is_a?(String) ? value : name.humanize
      end

      def arguments
        AiMcpServer.parameters_for_serialization(@tool_class.signature.fetch(:json_schema))
      end

      def argument_schema
        @tool_class.schema_value.fetch("inputSchema")
      end

      def invoke(arguments, actor:, llm: nil)
        @context ||=
          Agents::BotContext.new(
            user: actor,
            guardian: actor.guardian,
            feature_name: "workflow_mcp_tool",
          )
        output = @tool_class.new(arguments, context: @context, bot_user: actor, llm: llm).invoke
        output.fetch(:result, output)
      rescue ActiveRecord::RecordNotFound
        raise Client::Error
      end
    end
  end
end
