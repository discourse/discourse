# frozen_string_literal: true

if defined?(DiscourseWorkflows)
  module DiscourseWorkflows
    module Nodes
      module ToolAction
        OUTPUT_CONTRACTS = [
          {
            schema:
              DiscourseWorkflows::Schema.document(
                "result" => {
                  "description" => "The JSON value returned by the selected tool",
                },
              ),
          },
        ].freeze

        ARGUMENTS_PROPERTY = {
          type: :object,
          default: {
          },
          ui: {
            control: :ai_tool_arguments,
          },
        }.freeze

        def execute(exec_ctx)
          tool = resolve_tool(exec_ctx) if SiteSetting.discourse_ai_enabled
          if !tool
            raise_node_error!(I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.unavailable"))
          end

          llm = resolve_llm(exec_ctx, tool)
          actor = DiscourseWorkflows::AnonymousActor.new
          schemer = argument_validator(tool)
          inputs = exec_ctx.input_items
          arguments_by_item =
            inputs.each_index.map do |index|
              arguments = exec_ctx.get_node_parameter("arguments", index, default: {})
              exec_ctx.ensure_no_expression_errors!
              validate_arguments!(schemer, arguments, index)
              arguments
            end

          items =
            inputs.map.with_index do |item, index|
              raise DiscourseWorkflows::Executor::ExecutionTimedOut if exec_ctx.deadline&.past?
              result = invoke_tool(tool, arguments_by_item[index], actor, llm, index)
              wrap({ result: result }, paired_item: exec_ctx.paired_item_for(item))
            end

          [items]
        end

        private

        def resolve_llm(_exec_ctx, _tool)
          nil
        end

        def argument_validator(tool)
          JSONSchemer.schema(tool.argument_schema)
        rescue JSONSchemer::UnknownRef, JSONSchemer::InvalidRefResolution
          raise_node_error!(
            I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.invalid_schema"),
          )
        end

        def validate_arguments!(schemer, arguments, index)
          return if arguments.is_a?(Hash) && schemer.valid?(arguments)

          raise_node_error!(
            I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.invalid_arguments"),
            item_index: index,
          )
        rescue JSONSchemer::UnknownRef, JSONSchemer::InvalidRefResolution
          raise_node_error!(
            I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.invalid_schema"),
            item_index: index,
          )
        end

        def invoke_tool(tool, arguments, actor, llm, index)
          result = tool.invoke(arguments, actor: actor, llm: llm)
          return result if !result.is_a?(Hash) || !result.with_indifferent_access[:error].present?

          tool_failed!(index)
        rescue MiniRacer::Error,
               DiscourseAi::Agents::ToolRunner::TooManyRequestsError,
               Discourse::InvalidParameters,
               DiscourseAi::Mcp::Client::Error
          tool_failed!(index)
        end

        def tool_failed!(index)
          raise_node_error!(
            I18n.t("discourse_ai.discourse_workflows.ai_tool.errors.failed"),
            item_index: index,
          )
        end
      end
    end
  end
end
