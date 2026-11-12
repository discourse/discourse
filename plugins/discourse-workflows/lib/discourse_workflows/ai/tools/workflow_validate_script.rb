# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowValidateScript < Base
        RUN_ONCE_FOR_ALL_ITEMS = "runOnceForAllItems"
        RUN_ONCE_FOR_EACH_ITEM = "runOnceForEachItem"
        MODES = [RUN_ONCE_FOR_ALL_ITEMS, RUN_ONCE_FOR_EACH_ITEM].freeze
        DISALLOWED_FOR_EACH_METHODS = %w[first last all itemMatching].freeze
        MAX_INPUT_ITEMS = 20
        MAX_OUTPUT_ITEMS = 5
        MAX_OUTPUT_CHARS = 12_000
        MAX_OUTPUT_STRING_LENGTH = 4_000
        MAX_LOG_ENTRIES = 20
        MAX_LOG_LENGTH = 1_000
        MAX_CODE_BYTES = 20_000

        def self.signature
          {
            name: name,
            description:
              "Runs Code node JavaScript in the production workflow sandbox and returns a sample of output items, console logs, and errors. Use it to test scripts while writing them, including edge cases. With workflow_id, $(\"Node name\") defaults to data recorded by the workflow's last successful execution, and $input to the recorded input of node_id or the recorded output of input_node; input_items and node_outputs replace that with your own test data.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              required: %w[mode code],
              properties: {
                mode: {
                  type: "string",
                  description: MODES.join(" or "),
                },
                code: {
                  type: "string",
                  description: "JavaScript source",
                },
                workflow_id: {
                  type: "integer",
                  description: "Workflow whose last successful execution supplies default data.",
                },
                node_id: {
                  type: "string",
                  description:
                    "Existing Code node ID; its recorded input becomes the default $input.",
                },
                input_node: {
                  type: "string",
                  description:
                    "Name of the node a new Code node will follow; its recorded output becomes the default $input.",
                },
                input_output_index: {
                  type: "integer",
                  description:
                    "Output of input_node the new Code node connects to, such as 1 for a condition's false branch. Defaults to 0.",
                },
                input_items: {
                  type: "array",
                  description:
                    "Test items for $input, such as [{ \"json\": { ... } }]; [] tests empty input. At most #{MAX_INPUT_ITEMS}.",
                  items: {
                    type: "object",
                    additionalProperties: true,
                  },
                },
                node_outputs: {
                  type: "object",
                  description:
                    "Test output items keyed by node name, read via $(\"Node name\").first() or .all(). $(\"Node name\").item needs recorded paired items, so it only works with recorded data.",
                  additionalProperties: {
                    type: "array",
                    items: {
                      type: "object",
                      additionalProperties: true,
                    },
                  },
                },
              },
            },
          }
        end

        def self.name
          "workflow_validate_script"
        end

        # Checks that need no data, so they can run on proposals without knowing what the agent tested with.
        def self.static_errors(mode, code)
          errors = []
          errors << "Mode must be one of #{MODES.join(", ")}" if MODES.exclude?(mode)
          errors << "Code is required" if code.blank?
          errors << "Code exceeds #{MAX_CODE_BYTES} bytes" if code.bytesize > MAX_CODE_BYTES
          if mode == RUN_ONCE_FOR_EACH_ITEM
            code
              .scan(/\$input\.(#{DISALLOWED_FOR_EACH_METHODS.join("|")})\b/)
              .flatten
              .uniq
              .each do |method|
                errors << "$input.#{method} is only available in #{RUN_ONCE_FOR_ALL_ITEMS} mode"
              end
          end
          errors << syntax_error(code) if errors.empty?
          errors.compact
        end

        def self.syntax_error(code)
          js = MiniRacer::Context.new(timeout: 100)
          js.eval("new Function(#{code.to_json})")
          nil
        rescue MiniRacer::Error => e
          "JavaScript syntax error: #{e.message}"
        ensure
          js&.dispose
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          mode = parameters[:mode].to_s
          code = parameters[:code].to_s
          errors = self.class.static_errors(mode, code)
          return { status: "success", valid: false, errors: errors } if errors.present?

          workflow = DiscourseWorkflows::Workflow.find_by(id: parameters[:workflow_id])
          if parameters[:workflow_id].present? && workflow.blank?
            return error_response("Workflow not found")
          end

          @notes = []
          preview_context = preview_context(workflow)
          return error_response(@input_error) if @input_error

          run =
            DiscourseWorkflows::Workflow::Action::RunNodePreview.call(
              node_type_class: DiscourseWorkflows::Nodes::Code::V1,
              preview_context: preview_context,
              parameters: {
                "mode" => mode,
                "code" => code,
              },
              user: context.user,
            )
          output =
            DiscourseWorkflows::Ai::Sample.call(
              run[:outputs].first(1),
              totals: run[:output_counts]&.first(1),
              max_items: MAX_OUTPUT_ITEMS,
              max_chars: MAX_OUTPUT_CHARS,
              max_string_length: MAX_OUTPUT_STRING_LENGTH,
            )
          @notes << output[:truncated] if output[:truncated]

          {
            status: "success",
            valid: run[:error].blank?,
            errors: Array(run[:error]),
            input_count: run[:input_count],
            output: output[:outputs].first,
            logs: logs(Array(run[:log])),
            truncated: @notes.join(" ").presence,
          }.compact
        end

        private

        def preview_context(workflow)
          context =
            DiscourseWorkflows::Workflow::Action::BuildExpressionPreviewContext.call(
              workflow: workflow,
              node_id: parameters[:node_id],
            )

          node_outputs = json_safe(parameters[:node_outputs] || {})
          if !node_outputs.is_a?(Hash)
            @input_error = "node_outputs must be an object keyed by node name."
            return context
          end
          node_outputs.each do |name, items|
            next if name.start_with?("_", "$") # internal context keys, not node names
            context[name] = Array.wrap(items)
            context["__node_runs"]&.delete(name)
          end

          if !parameters[:input_items].nil?
            input_items = Array.wrap(json_safe(parameters[:input_items]))
            if input_items.length > MAX_INPUT_ITEMS
              @notes << "Only the first #{MAX_INPUT_ITEMS} of #{input_items.length} input_items were used."
            end
            context["__input_items"] = input_items.first(MAX_INPUT_ITEMS)
          elsif (input_node = parameters[:input_node].presence)
            context["__input_items"] = recorded_output(context, input_node)
          end

          context["__input_items"] ||= [{ "json" => {} }]
          context
        end

        def recorded_output(context, node_name)
          output_index = parameters[:input_output_index].to_i
          run = Array(context.dig("__node_runs", node_name)).last
          return Array(run.dig("outputs", output_index)) if run
          return Array.wrap(context[node_name]) if context.key?(node_name) && output_index.zero?

          @input_error =
            "No recorded output #{output_index} for #{node_name.inspect}; pass input_items instead."
          nil
        end

        def logs(entries)
          if entries.length > MAX_LOG_ENTRIES
            @notes << "Only the first #{MAX_LOG_ENTRIES} of #{entries.length} log entries are shown."
          end

          entries.first(MAX_LOG_ENTRIES).map { |entry| truncated_log_entry(entry) }
        end

        def truncated_log_entry(entry)
          entry.transform_values do |value|
            if value.is_a?(String)
              DiscourseWorkflows::Ai::Truncation.text(value, MAX_LOG_LENGTH)
            else
              value
            end
          end
        end
      end
    end
  end
end
