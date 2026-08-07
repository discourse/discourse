# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowGraphContext < Base
        def self.signature
          {
            name: name,
            description:
              "Returns the current draft workflow graph in a compact form for AI workflow authoring.",
            parameters: [
              {
                name: "workflow_id",
                description: "The workflow ID. Omit when creating a new workflow.",
                type: "integer",
                required: false,
              },
            ],
          }
        end

        def self.name
          "workflow_graph_context"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          workflow_id = parameters[:workflow_id].presence
          return empty_workflow_context if workflow_id.blank?

          workflow = DiscourseWorkflows::Workflow.find_by(id: workflow_id)
          return error_response("Workflow not found") if workflow.blank?

          nodes = workflow.nodes || []
          connections =
            DiscourseWorkflows::WorkflowDocument.connection_records(
              nodes,
              workflow.connections || {},
            )

          {
            status: "success",
            workflow: {
              id: workflow.id,
              name: workflow.name,
              published: workflow.published?,
              has_unpublished_changes: workflow.has_unpublished_changes?,
              version_id: workflow.version_id,
              active_version_id: workflow.active_version_id,
              graph_digest: DiscourseWorkflows::Ai::GraphDigest.call(workflow),
            },
            nodes: nodes.map { |node| serialize_node(node) },
            connections: connections.map { |connection| serialize_connection(connection, nodes) },
          }
        end

        private

        def empty_workflow_context
          { status: "success", workflow: nil, nodes: [], connections: [] }
        end

        def serialize_node(node)
          {
            id: node["id"],
            name: node["name"],
            type: node["type"],
            type_version: node["typeVersion"],
            parameters: DiscourseWorkflows::NodeData.parameters(node),
            position: node["position"],
          }
        end

        def serialize_connection(connection, nodes)
          nodes_by_id = nodes.index_by { |node| node["id"].to_s }
          source = nodes_by_id[connection["source_node_id"].to_s]
          target = nodes_by_id[connection["target_node_id"].to_s]

          {
            from_node_id: connection["source_node_id"],
            from_node_name: source&.dig("name"),
            to_node_id: connection["target_node_id"],
            to_node_name: target&.dig("name"),
            connection_type: connection["connection_type"],
            output_index: connection["source_output_index"],
            input_index: connection["target_input_index"],
          }
        end
      end
    end
  end
end
