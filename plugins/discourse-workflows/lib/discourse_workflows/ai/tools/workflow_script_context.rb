# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowScriptContext < Base
        AVAILABLE_VARIABLES = {
          "$input.item.json" => "Current item's JSON data",
          "$input.all()" => "Array of all input items; only valid in runOnceForAllItems mode",
          "$json" => "Shortcut for $input.item.json",
          "$(\"NodeName\").item" => "Paired item from another node",
          "$vars.KEY" => "Workflow variables",
          "$site_settings.NAME" => "Site settings",
          "$execution" => "Execution metadata",
          "$current_user" => "User running the workflow",
          "console.log" => "Workflow execution log",
        }.freeze

        RETURN_CONTRACT = {
          "runOnceForAllItems" =>
            "Return an array of items. Each item should be { json: { ... } } or a plain object that can be normalized.",
          "runOnceForEachItem" =>
            "Return one object per input item. Do not return an array in this mode.",
          "reserved_top_level_keys" => %w[json pairedItem error index],
        }.freeze

        MODE_RESTRICTIONS = {
          "runOnceForEachItem" => {
            "disallowed_input_methods" => %w[
              $input.first
              $input.last
              $input.all
              $input.itemMatching
            ],
          },
        }.freeze

        EXAMPLES = [
          {
            name: "Add a derived field to each item",
            mode: "runOnceForAllItems",
            code:
              "var items = $input.all();\n" \
                "items.forEach(function(item) {\n" \
                "  item.json.summary = item.json.topic && item.json.topic.title;\n" \
                "});\n" \
                "return items;",
          },
          {
            name: "Build one Markdown reply from all items",
            mode: "runOnceForAllItems",
            code:
              "var lines = $input.all().map(function(item) {\n" \
                "  return '- ' + item.json.title;\n" \
                "});\n" \
                "return [{ json: { raw: lines.join('\\n') } }];",
          },
        ].freeze

        def self.signature
          {
            name: name,
            description:
              "Returns the runtime, input, output, sample data, and return-contract context needed to write a workflow Code node script.",
            parameters: [
              { name: "workflow_id", description: "Workflow ID", type: "integer", required: false },
              {
                name: "target_node_id",
                description: "Existing Code node ID when editing a script",
                type: "string",
                required: false,
              },
              {
                name: "upstream_node_id",
                description: "Node ID that feeds the Code node",
                type: "string",
                required: false,
              },
              {
                name: "downstream_node_id",
                description: "Node ID that consumes the Code node output",
                type: "string",
                required: false,
              },
              {
                name: "sample_limit",
                description: "Maximum number of pinned sample items to return",
                type: "integer",
                required: false,
              },
            ],
          }
        end

        def self.name
          "workflow_script_context"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          workflow = find_workflow
          if parameters[:workflow_id].present? && workflow.blank?
            return error_response("Workflow not found")
          end

          @workflow_for_shape = workflow
          nodes = workflow&.nodes || []
          target_node = find_node(nodes, parameters[:target_node_id])
          upstream_node = find_node(nodes, parameters[:upstream_node_id])
          downstream_node = find_node(nodes, parameters[:downstream_node_id])

          {
            status: "success",
            runtime: runtime,
            available_variables: AVAILABLE_VARIABLES,
            return_contract: RETURN_CONTRACT,
            mode_restrictions: MODE_RESTRICTIONS,
            upstream_fields: node_fields(upstream_node),
            downstream_requirements: downstream_requirements(downstream_node),
            sample_input_items: sample_input_items(workflow, upstream_node),
            existing_code: existing_code(target_node),
            examples: EXAMPLES,
          }
        end

        private

        def find_workflow
          workflow_id = parameters[:workflow_id].presence
          return nil if workflow_id.blank?

          DiscourseWorkflows::Workflow.find_by(id: workflow_id)
        end

        def find_node(nodes, node_id)
          return nil if node_id.blank?

          nodes.find { |node| node["id"].to_s == node_id.to_s }
        end

        def runtime
          {
            language: "javascript",
            node_type: "action:code",
            version: "1.0",
            modes: %w[runOnceForAllItems runOnceForEachItem],
            default_mode: "runOnceForAllItems",
          }
        end

        def node_fields(node)
          return nil if node.blank?

          schemas = infer_schema_from_pin_data(node)
          schemas =
            workflow_schema_resolution[:output_schemas][node["id"].to_s] || [] if schemas.nil?
          output_fields = schemas.map { |schema| DiscourseAi::WorkflowSchemaFields.convert(schema) }

          {
            node_id: node["id"],
            node_name: node["name"],
            node_type: node["type"],
            output_fields: output_fields,
          }
        end

        def workflow_schema_resolution
          @workflow_schema_resolution ||=
            DiscourseWorkflows::Schema.resolve_graph(
              @workflow_for_shape&.nodes,
              @workflow_for_shape&.connections,
            )
        end

        def infer_schema_from_pin_data(node)
          pin_data = @workflow_for_shape&.node_pin_data(node["name"])
          return nil if pin_data.blank?

          sample = pin_data.first
          [DiscourseWorkflows::Schema.infer(sample&.dig("json") || {})]
        end

        def downstream_requirements(node)
          return nil if node.blank?

          node_type =
            DiscourseWorkflows::Registry.find_node_type(node["type"], version: node["typeVersion"])
          properties = node_type&.properties || {}
          required_fields =
            properties.each_with_object({}) do |(name, property), result|
              next unless property[:required]

              result[name.to_s] = property[:type].to_s
            end

          {
            node_id: node["id"],
            node_name: node["name"],
            node_type: node["type"],
            required_fields: required_fields,
          }
        end

        def sample_input_items(workflow, upstream_node)
          return [] if workflow.blank? || upstream_node.blank?

          limit = parameters[:sample_limit].presence&.to_i || 5
          Array.wrap(workflow.node_pin_data(upstream_node["name"])).first(limit)
        end

        def existing_code(node)
          return nil if node.blank? || node["type"] != "action:code"

          DiscourseWorkflows::NodeData.parameters(node)["code"]
        end
      end
    end
  end
end
