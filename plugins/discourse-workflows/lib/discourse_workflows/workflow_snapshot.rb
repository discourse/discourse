# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSnapshot
    SnapshotNode =
      Struct.new(:id, :type, :type_version, :name, :position, :configuration, keyword_init: true)

    SnapshotConnection =
      Struct.new(:source_node_id, :source_output, :target_node_id, keyword_init: true)

    attr_reader :nodes, :connections

    def initialize(workflow_data)
      data = workflow_data.deep_stringify_keys
      @nodes_by_id = {}
      @nodes =
        data
          .fetch("nodes") { [] }
          .map do |n|
            node =
              SnapshotNode.new(
                id: n["id"].to_s,
                type: n["type"],
                type_version: n.fetch("type_version") { Registry::DEFAULT_VERSION },
                name: n["name"],
                position: n["position"],
                configuration: n.fetch("configuration") { {} },
              )
            @nodes_by_id[node.id] = node
            node
          end

      @connections =
        data
          .fetch("connections") { [] }
          .map do |c|
            SnapshotConnection.new(
              source_node_id: c["source_node_id"].to_s,
              source_output: c.fetch("source_output") { "main" },
              target_node_id: c["target_node_id"].to_s,
            )
          end

      @connections_by_source = @connections.group_by(&:source_node_id)
    end

    def find_node(node_id)
      @nodes_by_id[node_id.to_s]
    end

    def connections_from(node)
      @connections_by_source.fetch(node.id) { [] }
    end

    def target_node(connection)
      @nodes_by_id[connection.target_node_id]
    end

    def self.snapshot(workflow)
      { "nodes" => workflow.parsed_nodes, "connections" => workflow.parsed_connections }
    end
  end
end
