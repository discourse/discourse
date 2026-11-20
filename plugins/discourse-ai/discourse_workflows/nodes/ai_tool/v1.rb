# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module AiTool
        class V1 < NodeType
          include ToolAction

          description(
            name: "action:ai_tool",
            version: "1.0",
            defaults: {
              icon: "wrench",
              color: "pink",
            },
            group: "ai",
            available: -> { SiteSetting.discourse_ai_enabled },
            unavailable_reason_key: "discourse_workflows.node_unavailable.requires_ai",
            i18n_prefix: "discourse_ai.discourse_workflows",
            output_contracts: OUTPUT_CONTRACTS,
            properties: {
              tool_ref: {
                type: :string,
                required: true,
                no_data_expression: true,
                type_options: {
                  load_options_method: "tools",
                },
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                  resets: %w[arguments llm_model_id],
                  set_from_option: {
                    custom_tool: "custom",
                  },
                },
              },
              custom_tool: {
                type: :boolean,
                default: false,
                ui: {
                  hidden: true,
                },
              },
              llm_model_id: {
                type: :integer,
                no_data_expression: true,
                type_options: {
                  load_options_method: "llm_models",
                },
                ui: {
                  control: :combo_box,
                },
                control_options: {
                  filterable: true,
                },
                display_options: {
                  show: {
                    custom_tool: [true],
                  },
                },
              },
              arguments: ARGUMENTS_PROPERTY,
            },
          )

          def self.group_definition
            AiAgent::V1.group_definition
          end

          def self.load_options_context(context)
            return if !SiteSetting.discourse_ai_enabled

            case context.method_name
            when "tools"
              DiscourseAi::Agents::WorkflowTool.options.select do |option|
                context.matches_filter?(option[:name])
              end
            when "tool_arguments"
              DiscourseAi::Agents::WorkflowTool.find(
                context.get_current_node_parameter("tool_ref"),
              )&.arguments
            when "llm_models"
              AiAgent::V1.llm_model_options(context)
            end
          end

          private

          def resolve_tool(exec_ctx)
            DiscourseAi::Agents::WorkflowTool.find(exec_ctx.get_node_parameter("tool_ref"))
          end

          def resolve_llm(exec_ctx, tool)
            return if !tool.custom?

            model_id = exec_ctx.get_node_parameter("llm_model_id")
            return if model_id.blank?

            model = ::LlmModel.find_by(id: model_id)
            if !model
              raise_node_error!(
                I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.llm_not_found"),
              )
            end
            model.to_llm
          end
        end
      end
    end
  end
end
