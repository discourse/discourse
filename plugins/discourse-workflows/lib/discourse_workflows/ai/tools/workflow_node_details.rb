# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowNodeDetails < Base
        MAX_NODES = 10

        def self.signature
          {
            name: name,
            description:
              "Returns full details for nodes in the current workflow: parameters (including Code node scripts), connections, input/output fields, and a truncated sample of recorded output from pinned data or the last successful execution.",
            json_schema: {
              type: "object",
              additionalProperties: false,
              required: %w[workflow_id node_ids],
              properties: {
                workflow_id: {
                  type: "integer",
                  description: "Workflow ID.",
                },
                node_ids: {
                  type: "array",
                  description: "Node IDs or names from the workflow outline, at most #{MAX_NODES}.",
                  items: {
                    type: "string",
                  },
                },
              },
            },
          }
        end

        def self.name
          "workflow_node_details"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          workflow = DiscourseWorkflows::Workflow.find_by(id: parameters[:workflow_id])
          return error_response("Workflow not found") if workflow.blank?

          @workflow = workflow
          refs = Array.wrap(parameters[:node_ids]).map(&:to_s).uniq
          nodes_by_ref = refs.first(MAX_NODES).index_with { |ref| find_node(ref) }

          result = {
            status: "success",
            nodes: nodes_by_ref.values.compact.map { |node| node_details(node) },
            not_found: nodes_by_ref.select { |_ref, node| node.nil? }.keys,
          }
          if refs.length > MAX_NODES
            result[
              :truncated
            ] = "Only the first #{MAX_NODES} of #{refs.length} requested nodes are included."
          end
          result
        end

        private

        def find_node(ref)
          nodes = @workflow.nodes || []
          nodes.find { |node| node["id"].to_s == ref } || nodes.find { |node| node["name"] == ref }
        end

        def node_details(node)
          node_id = node["id"].to_s
          {
            id: node_id,
            name: node["name"],
            type: node["type"],
            type_version: node["typeVersion"],
            parameters: DiscourseWorkflows::NodeData.parameters(node),
            incoming: connections_where("target_node_id", node_id, "source_node_id"),
            outgoing: connections_where("source_node_id", node_id, "target_node_id"),
            input_fields: expression_fields(graph[:input_schemas][node_id]),
            output_fields: expression_fields(graph[:output_schemas][node_id]),
            recorded_output: recorded_output(node),
          }
        end

        def connections_where(key, node_id, other_key)
          graph[:connection_records]
            .select { |connection| connection[key].to_s == node_id }
            .map do |connection|
              other_id = connection[other_key].to_s
              {
                node_id: other_id,
                node_name: find_node(other_id)&.dig("name"),
                output_index: connection["source_output_index"].to_i,
                input_index: connection["target_input_index"].to_i,
                connection_type: connection["connection_type"].to_s.presence || "main",
              }
            end
        end

        def graph
          @graph ||=
            DiscourseWorkflows::Schema.resolve_graph(@workflow.nodes, @workflow.connections)
        end

        def expression_fields(schemas)
          Array(schemas).map do |schema|
            DiscourseAi::WorkflowSchemaFields
              .convert(schema)
              .transform_keys { |path| path.start_with?("[") ? "$json#{path}" : "$json.#{path}" }
          end
        end

        def recorded_output(node)
          pinned = @workflow.node_pin_data(node["name"])
          return { source: "pinned", **Sample.call([pinned]) } if pinned.present?

          execution_id = preview_context.dig("__execution", "id").to_i
          if execution_id.zero?
            return { source: "none", note: "The workflow has no successful execution yet." }
          end

          run = Array(preview_context.dig("__node_runs", node["name"])).last
          if run.blank?
            return(
              {
                source: "none",
                note:
                  "This node has no successful run in the last successful execution (##{execution_id}): it was skipped or failed, so no sample exists. This is different from running and producing no items.",
              }
            )
          end

          { source: "execution", execution_id: execution_id, **Sample.call(run["outputs"]) }
        end

        def preview_context
          @preview_context ||=
            DiscourseWorkflows::Workflow::Action::BuildExpressionPreviewContext.call(
              workflow: @workflow,
            )
        end
      end
    end
  end
end
