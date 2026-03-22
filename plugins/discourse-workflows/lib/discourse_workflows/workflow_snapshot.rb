# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSnapshot
    SnapshotNode =
      Struct.new(:id, :type, :name, :position, :configuration, keyword_init: true) do
        include NodeTypeChecks
      end

    SnapshotConnection =
      Struct.new(:source_node_id, :source_output, :target_node_id, keyword_init: true)

    attr_reader :nodes, :connections

    def initialize(workflow_data)
      data = workflow_data.deep_stringify_keys
      @nodes_by_id = {}
      @nodes =
        (data["nodes"] || []).map do |n|
          node =
            SnapshotNode.new(
              id: n["id"],
              type: n["type"],
              name: n["name"],
              position: n["position"],
              configuration: (n["configuration"] || {}).deep_stringify_keys,
            )
          @nodes_by_id[node.id] = node
          node
        end

      @connections =
        (data["connections"] || []).map do |c|
          SnapshotConnection.new(
            source_node_id: c["source_node_id"],
            source_output: c["source_output"] || "main",
            target_node_id: c["target_node_id"],
          )
        end

      @connections_by_source = @connections.group_by(&:source_node_id)
    end

    def find_node(node_id)
      @nodes_by_id[node_id]
    end

    def connections_from(node)
      @connections_by_source[node.id] || []
    end

    def target_node(connection)
      @nodes_by_id[connection.target_node_id]
    end

    def self.snapshot(workflow)
      {
        "nodes" =>
          workflow
            .nodes
            .order(:position_index)
            .map do |n|
              {
                "id" => n.id,
                "type" => n.type,
                "name" => n.name,
                "position" => n.position,
                "configuration" => n.configuration,
              }
            end,
        "connections" =>
          workflow.connections.map do |c|
            {
              "source_node_id" => c.source_node_id,
              "source_output" => c.source_output,
              "target_node_id" => c.target_node_id,
            }
          end,
      }
    end
  end
end
