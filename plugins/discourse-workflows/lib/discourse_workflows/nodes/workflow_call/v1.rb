# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module WorkflowCall
      class V1 < NodeType
        AUTO = "auto"
        MANUAL = "manual"
        MAPPING_MODES = [AUTO, MANUAL].freeze

        description(
          name: "action:workflow_call",
          version: "1.0",
          defaults: {
            icon: "arrows-turn-to-dots",
            color: "teal",
          },
          group: "flow",
          capabilities: {
            waits_for_resume: true,
          },
          properties: {
            workflow_id: {
              type: :integer,
              required: true,
              no_data_expression: true,
              type_options: {
                load_options_method: "callable_workflows",
              },
              ui: {
                control: :combo_box,
              },
              control_options: {
                action_icon: "up-right-from-square",
                action_label: "discourse_workflows.workflow_call.open_workflow",
                action_route: "adminPlugins.show.discourse-workflows.show",
                action_route_models: [{ source: "field_value" }],
                value_property: "id",
                name_property: "name",
                filterable: true,
                none: "discourse_workflows.workflow_call.workflow_id_placeholder",
              },
            },
            mapping_mode: {
              type: :options,
              required: true,
              default: AUTO,
              options: MAPPING_MODES,
              no_data_expression: true,
            },
            fields: {
              type: :assignment_collection,
              required: false,
              default: {
                assignments: [],
              },
              type_options: {
                assignment_types: %w[string number boolean array object],
              },
              display_options: {
                show: {
                  mapping_mode: [MANUAL],
                },
              },
            },
          },
          i18n_scope: "workflow_call",
        )

        def self.load_options_context(context)
          case context.method_name
          when "callable_workflows"
            callable_workflow_options(context)
          end
        end

        def self.callable_workflow_options(context)
          scope =
            DiscourseWorkflows::Workflow
              .published
              .joins(:workflow_dependencies)
              .where(
                discourse_workflows_workflow_dependencies: {
                  dependency_type: "node_type",
                  dependency_key: DiscourseWorkflows::Nodes::WorkflowCallTrigger::V1.identifier,
                },
              )
              .where(
                "discourse_workflows_workflows.active_version_id = " \
                  "discourse_workflows_workflow_dependencies.workflow_version_id",
              )
          scope = scope.where.not(id: context.workflow_id) if context.workflow_id.present?
          scope = scope.filter_by_name(context.filter) if context.filter.present?

          scope.distinct.order(:name).pluck(:id, :name).map { |id, name| { id:, name: } }
        end
        private_class_method :callable_workflow_options

        def execute(exec_ctx)
          mapping_mode = exec_ctx.get_node_parameter("mapping_mode", 0, default: AUTO)

          call = prepare_call(exec_ctx, mapping_mode:)

          exec_ctx.put_execution_to_wait(
            nil,
            kind: "workflow_call",
            payload: wait_payload(exec_ctx, call),
          )
          [exec_ctx.input_items]
        end

        private

        def prepare_call(exec_ctx, mapping_mode:)
          WorkflowCallPreparer.new(
            exec_ctx:,
            workflow_id: exec_ctx.get_node_parameter("workflow_id", 0),
            trigger_data: trigger_data(exec_ctx, mapping_mode),
          ).prepare
        end

        def trigger_data(exec_ctx, mapping_mode)
          return manual_trigger_data(exec_ctx) if mapping_mode == MANUAL

          exec_ctx.input_items.map { |item| item.fetch("json") { {} } }
        end

        def manual_trigger_data(exec_ctx)
          exec_ctx.input_items.map.with_index { |_item, index| manual_payload(exec_ctx, index) }
        end

        def manual_payload(exec_ctx, item_index)
          exec_ctx
            .get_node_parameter("fields.assignments", item_index, default: [])
            .each_with_object({}) do |field, result|
              key = field["name"].to_s
              next if key.blank?

              value = cast_value(field["value"], field.fetch("type") { "string" })
              set_field(result, key, value)
            end
        end

        def cast_value(value, type)
          cast_value!(value, type)
        rescue JSON::ParserError, ArgumentError => e
          raise_node_error!("Invalid field value", description: e.message)
        end

        def cast_value!(value, type)
          case type
          when "number"
            Float(value)
          when "boolean"
            return value if value == true || value == false

            %w[true 1].include?(value.to_s.downcase)
          when "array"
            cast_json_value(value, Array)
          when "object"
            cast_json_value(value, Hash)
          else
            value.to_s
          end
        end

        def cast_json_value(value, expected_class)
          return value if value.is_a?(expected_class)

          parsed = JSON.parse(value.to_s)
          return parsed if parsed.is_a?(expected_class)

          expected_type = expected_class == Array ? "array" : "object"
          raise_node_error!("Invalid field value", description: "Expected #{expected_type}")
        end

        def set_field(result, field, value)
          if field.exclude?(".")
            result[field] = value
            return
          end

          keys = field.split(".")
          leaf = keys.pop
          target = result
          keys.each do |key|
            target[key] = {} unless target[key].is_a?(Hash)
            target = target[key]
          end
          target[leaf] = value
        end

        def wait_payload(exec_ctx, call)
          {
            "user_id" => exec_ctx.user&.id,
            "call" => {
              "workflow_id" => call.workflow.id,
              "workflow_version_id" => call.workflow_version.version_id,
              "trigger_data" => call.trigger_data,
            },
          }
        end
      end
    end
  end
end
