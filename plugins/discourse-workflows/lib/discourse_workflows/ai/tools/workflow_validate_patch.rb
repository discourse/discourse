# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowValidatePatch < Base
        def self.signature
          {
            name: name,
            description:
              "Dry-runs a workflow patch and returns validation errors, normalized graph data, inferred node input/output schemas, proposed created resources, and a diff summary without saving anything.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              required: %w[operations],
              properties: {
                workflow_id: {
                  type: "integer",
                  description: "Workflow ID.",
                },
                workflow_name: {
                  type: "string",
                  description: "Name to use when validating a brand-new workflow patch.",
                },
                operations: {
                  type: "array",
                  description:
                    "Array of workflow patch operation objects. Each item must be an object, not a JSON string.",
                  items: {
                    type: "object",
                    additionalProperties: true,
                  },
                },
              },
            },
          }
        end

        def self.name
          "workflow_validate_patch"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          workflow = find_or_build_workflow
          result =
            DiscourseWorkflows::Workflow::Action::ApplyPatch.call(
              workflow: workflow,
              operations: normalized_patch_operations(parameters[:operations]),
              persist: false,
            )

          if result[:valid]
            schemas = node_schemas(result[:nodes], result[:connections])
            graph_errors = connection_validation_errors(result[:nodes], result[:connections])
            expression_errors = expression_validation_errors(result[:nodes], schemas)
          else
            schemas = []
            graph_errors = []
            expression_errors = []
          end

          valid = result[:valid] && graph_errors.blank? && expression_errors.blank?
          errors = Array.wrap(result[:errors]) + graph_errors + expression_errors

          {
            status: "success",
            valid: valid,
            errors: errors,
            graph_errors: graph_errors,
            expression_errors: expression_errors,
            normalized_graph:
              result[:valid] ? { nodes: result[:nodes], connections: result[:connections] } : nil,
            node_schemas: schemas,
            diff: result[:diff],
            created_resources: Array.wrap(result[:created_resources]),
          }
        end

        private

        PASS_THROUGH_NODE_TYPES = %w[condition:filter condition:if action:limit flow:wait].freeze
        CONDITION_NODE_TYPES = %w[condition:filter condition:if].freeze

        JSON_REFERENCE_REGEX = /\$json(?:\.[A-Za-z_][A-Za-z0-9_]*)+/
        MAX_AVAILABLE_PATHS = 12

        FIXED_OUTPUT_SCHEMAS = {
          "action:send_chat_message" => {
            "channel_id" => "integer",
            "message" => "string",
          },
        }.freeze

        def node_schemas(nodes, connections)
          connection_records =
            DiscourseWorkflows::WorkflowDocument.connection_records(nodes, connections)
          output_schemas = {}
          input_schemas = {}

          (nodes.length + 1).times do
            changed = false

            nodes.each do |node|
              node_id = node["id"].to_s
              next_input_schema = input_schema_for(node_id, connection_records, output_schemas)
              next_output_schema = output_schema_for(node, next_input_schema)

              if input_schemas[node_id] != next_input_schema ||
                   output_schemas[node_id] != next_output_schema
                input_schemas[node_id] = next_input_schema
                output_schemas[node_id] = next_output_schema
                changed = true
              end
            end

            break if !changed
          end

          nodes.map do |node|
            node_id = node["id"].to_s
            {
              node_id: node_id,
              node_name: node["name"],
              node_type: node["type"],
              input_schema: expression_schema(input_schemas[node_id] || {}),
              output_schema: expression_schema(output_schemas[node_id] || {}),
              input_sources: input_sources(node_id, nodes, connection_records, output_schemas),
            }
          end
        end

        def input_schema_for(node_id, connection_records, output_schemas)
          incoming = incoming_connections(node_id, connection_records)
          return {} if incoming.blank?

          incoming.each_with_object({}) do |connection, result|
            result.merge!(output_schemas[connection["source_node_id"].to_s] || {})
          end
        end

        def output_schema_for(node, input_schema)
          catalog_schema =
            DiscourseWorkflows::Ai::Tools::WorkflowNodeCatalog.output_schema_for(
              node["type"],
              parameters: node["parameters"] || {},
              input_schema: input_schema,
            )
          return catalog_schema if catalog_schema.present?
          return input_schema if PASS_THROUGH_NODE_TYPES.include?(node["type"].to_s)

          FIXED_OUTPUT_SCHEMAS.fetch(node["type"].to_s, {})
        end

        def input_sources(node_id, nodes, connection_records, output_schemas)
          nodes_by_id = nodes.index_by { |node| node["id"].to_s }
          incoming_connections(node_id, connection_records).map do |connection|
            source_node = nodes_by_id[connection["source_node_id"].to_s]
            {
              source_node_id: connection["source_node_id"].to_s,
              source_node_name: source_node&.dig("name"),
              source_node_type: source_node&.dig("type"),
              output_index: connection["source_output_index"],
              input_index: connection["target_input_index"],
              schema: expression_schema(output_schemas[connection["source_node_id"].to_s] || {}),
            }
          end
        end

        def connection_validation_errors(nodes, connections)
          connection_records =
            DiscourseWorkflows::WorkflowDocument.connection_records(nodes, connections)
          nodes_by_id = nodes.index_by { |node| node["id"].to_s }

          connection_records.filter_map do |connection|
            source_node = nodes_by_id[connection["source_node_id"].to_s]
            next if source_node.blank?

            connection_type = connection["connection_type"].to_s.presence || "main"
            valid_types = output_connection_types(source_node)
            next if valid_types.include?(connection_type)

            "#{node_label(source_node)} output connection_type #{connection_type.inspect} is invalid for #{source_node["type"]}. Use one of: #{valid_types.join(", ")}."
          end
        end

        def output_connection_types(node)
          node_class =
            DiscourseWorkflows::Registry.find_node_type(node["type"], version: node["typeVersion"])
          outputs = Array.wrap(node_class&.outputs(node["parameters"] || {}) || [:main])
          outputs.map do |output|
            output.respond_to?(:to_h) ? output.to_h.with_indifferent_access[:key].to_s : output.to_s
          end
        end

        def incoming_connections(node_id, connection_records)
          connection_records
            .select { |connection| connection["target_node_id"].to_s == node_id.to_s }
            .sort_by do |connection|
              [connection["target_input_index"].to_i, connection["source_output_index"].to_i]
            end
        end

        def expression_schema(schema)
          schema.transform_keys { |key| key.to_s.start_with?("$json") ? key.to_s : "$json.#{key}" }
        end

        def expression_validation_errors(nodes, schemas)
          schemas_by_node_id = schemas.index_by { |schema| schema[:node_id].to_s }

          nodes.flat_map do |node|
            schema = schemas_by_node_id[node["id"].to_s] || {}
            input_schema = schema[:input_schema] || {}
            expression_errors_for_node(node, input_schema) + condition_configuration_errors(node)
          end
        end

        def expression_errors_for_node(node, input_schema)
          parameter_values(node["parameters"] || {}).flat_map do |path, value|
            next [] if !value.is_a?(String)

            errors = []
            if unprefixed_template_expression?(value)
              errors << "#{node_label(node)} parameter #{path} contains {{ }} expressions but does not start with =. Prefix dynamic template strings with =, for example =Text {{ $json.topic.id }}."
            end

            if invalid_bare_json_expression?(value)
              errors << "#{node_label(node)} parameter #{path} references $json in an expression string without {{ }}. Use ={{ $json.field }} for whole-field values or =Text {{ $json.field }} for template strings."
            end

            errors + unavailable_json_path_errors(node, path, value, input_schema)
          end
        end

        def condition_configuration_errors(node)
          return [] if !CONDITION_NODE_TYPES.include?(node["type"].to_s)

          conditions = Array.wrap((node["parameters"] || {})["conditions"])
          conditions.flat_map.with_index do |condition, index|
            condition = condition.respond_to?(:to_h) ? condition.to_h.with_indifferent_access : {}
            condition_index = index + 1
            errors = []

            if condition[:leftValue].blank?
              hint = condition.key?(:left) ? " Use leftValue instead of left." : ""
              errors << "#{node_label(node)} condition #{condition_index} must set leftValue.#{hint}"
            elsif invalid_condition_value?(condition[:leftValue])
              errors << "#{node_label(node)} condition #{condition_index} leftValue must be a scalar or expression string, not an object."
            end

            operator = condition[:operator].respond_to?(:to_h) ? condition[:operator].to_h : {}
            operator = operator.with_indifferent_access
            if operator[:type].blank?
              errors << "#{node_label(node)} condition #{condition_index} must set operator.type."
            end
            if operator[:operation].blank?
              errors << "#{node_label(node)} condition #{condition_index} must set operator.operation."
            end

            if !operator[:singleValue] && !condition.key?(:rightValue)
              hint = condition.key?(:right) ? " Use rightValue instead of right." : ""
              errors << "#{node_label(node)} condition #{condition_index} must set rightValue for #{operator[:operation].presence || "this"} comparisons.#{hint}"
            elsif condition.key?(:rightValue) && invalid_condition_value?(condition[:rightValue])
              errors << "#{node_label(node)} condition #{condition_index} rightValue must be a scalar or expression string, not an object."
            end

            errors
          end
        end

        def invalid_condition_value?(value)
          value.is_a?(Hash) || value.is_a?(Array)
        end

        def parameter_values(value, prefix = nil)
          case value
          when Hash
            value.flat_map do |key, nested_value|
              parameter_values(nested_value, [prefix, key].compact.join("."))
            end
          when Array
            value.flat_map.with_index do |nested_value, index|
              parameter_values(nested_value, "#{prefix}[#{index}]")
            end
          else
            [[prefix || "parameters", value]]
          end
        end

        def unprefixed_template_expression?(value)
          value.include?("{{") && value.include?("}}") && !value.start_with?("=")
        end

        def invalid_bare_json_expression?(value)
          value.start_with?("=") && value.include?("$json") && !value.include?("{{")
        end

        def unavailable_json_path_errors(node, parameter_path, value, input_schema)
          references = value.scan(JSON_REFERENCE_REGEX).uniq
          return [] if references.blank? || input_schema.blank?

          references.filter_map do |reference|
            next if schema_path_available?(reference, input_schema)

            "#{node_label(node)} parameter #{parameter_path} references #{reference}, but that path is not available in this node's input schema. Available paths: #{available_paths_summary(input_schema)}."
          end
        end

        def schema_path_available?(reference, input_schema)
          schema_paths = input_schema.keys.map(&:to_s)
          return true if schema_paths.include?(reference)
          return true if schema_paths.any? { |path| path.start_with?("#{reference}.") }

          segments = reference.split(".")
          while segments.length > 2
            segments.pop
            return true if schema_paths.include?(segments.join("."))
          end

          false
        end

        def available_paths_summary(input_schema)
          paths = input_schema.keys.map(&:to_s).sort
          summary = paths.first(MAX_AVAILABLE_PATHS).join(", ")
          summary += ", ..." if paths.length > MAX_AVAILABLE_PATHS
          summary.presence || "none"
        end

        def node_label(node)
          node["name"].presence || node["id"].presence || node["type"]
        end

        def normalized_patch_operations(operations)
          Array
            .wrap(operations)
            .filter_map do |operation|
              if operation.is_a?(String)
                parse_json_hash(operation.strip) || operation
              else
                operation
              end
            end
        end

        def parse_json_hash(candidate)
          parsed = JSON.parse(candidate)
          parsed if parsed.is_a?(Hash)
        rescue JSON::ParserError, Oj::ParseError
          nil
        end

        def find_or_build_workflow
          workflow_id = parameters[:workflow_id].presence
          return DiscourseWorkflows::Workflow.find(workflow_id) if workflow_id.present?

          DiscourseWorkflows::Workflow.new(
            name: parameters[:workflow_name].presence || "AI workflow draft",
            created_by: context.user,
            nodes: [],
            connections: {
            },
          )
        end
      end
    end
  end
end
