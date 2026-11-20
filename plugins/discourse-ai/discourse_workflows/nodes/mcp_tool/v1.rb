# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module McpTool
        class V1 < NodeType
          include ToolAction

          description(
            name: "action:mcp_tool",
            version: "1.0",
            defaults: {
              icon: "plug",
              color: "pink",
            },
            group: "ai",
            available: -> { SiteSetting.discourse_ai_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_ai",
            i18n_prefix: "discourse_ai.discourse_workflows",
            output_contracts: OUTPUT_CONTRACTS,
            properties: {
              mcp_server_id: {
                type: :integer,
                required: true,
                no_data_expression: true,
                type_options: {
                  load_options_method: "servers",
                },
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  resets: %w[tool_name arguments],
                },
              },
              tool_name: {
                type: :string,
                required: true,
                no_data_expression: true,
                type_options: {
                  load_options_method: "tools",
                  load_options_depends_on: ["mcp_server_id"],
                },
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  resets: ["arguments"],
                },
                display_options: {
                  show: {
                    mcp_server_id: [{ condition: { exists: true } }],
                  },
                },
              },
              arguments:
                ARGUMENTS_PROPERTY.merge(
                  control_options: {
                    signature_parameters: %w[mcp_server_id tool_name],
                  },
                ),
            },
          )

          def self.group_definition
            AiAgent::V1.group_definition
          end

          def self.load_options_context(context)
            return if !SiteSetting.discourse_ai_enabled

            catalog = DiscourseAi::Mcp::WorkflowTool
            server_id = context.get_current_node_parameter("mcp_server_id")
            case context.method_name
            when "servers"
              catalog.servers.filter_map do |server|
                { id: server.id, name: server.name } if context.matches_filter?(server.name)
              end
            when "tools"
              catalog
                .tools(server_id)
                .filter_map do |tool|
                  if context.matches_filter?(tool.title) || context.matches_filter?(tool.name)
                    { id: tool.name, name: tool.title }
                  end
                end
            when "tool_arguments"
              tool_name = context.get_current_node_parameter("tool_name")
              catalog.find(server_id, tool_name)&.arguments || []
            end
          end

          private

          def resolve_tool(exec_ctx)
            server_id = exec_ctx.get_node_parameter("mcp_server_id")
            tool_name = exec_ctx.get_node_parameter("tool_name")
            DiscourseAi::Mcp::WorkflowTool.find(server_id, tool_name)
          end
        end
      end
    end
  end
end
