# frozen_string_literal: true

module DiscourseWorkflows
  class WorkflowSnapshot
    SnapshotNode =
      Struct.new(
        :id,
        :type,
        :type_version,
        :name,
        :position,
        :parameters,
        :credentials,
        :webhook_id,
        :notes,
        :notes_in_flow,
        :always_output_data,
        :on_error,
        :continue_on_fail,
        keyword_init: true,
      ) do
        def resolved_parameters
          NodeData.resolved_parameters(self)
        end

        def to_workflow_node
          {
            "id" => id,
            "type" => type,
            "typeVersion" => type_version,
            "name" => name,
            "position" => position,
            "parameters" => parameters,
            "credentials" => credentials,
            "webhookId" => webhook_id,
          }.merge(NodeData.direct_settings(self)).compact
        end
      end

    SnapshotConnection =
      Struct.new(
        :source_node_id,
        :source_output_index,
        :target_node_id,
        :target_input_index,
        :connection_type,
        keyword_init: true,
      )

    attr_reader :nodes, :connections, :pin_data, :workflow_name

    def initialize(workflow_data)
      data = workflow_data.deep_stringify_keys
      @workflow_name = data["name"]
      @pin_data = data["pinData"] || {}
      @nodes =
        data
          .fetch("nodes") { [] }
          .map do |n|
            SnapshotNode.new(
              id: n["id"].to_s,
              type: n["type"],
              type_version: n["typeVersion"] || Registry::DEFAULT_VERSION,
              name: n["name"],
              position: n["position"],
              parameters: n["parameters"] || {},
              credentials: n["credentials"] || {},
              webhook_id: n["webhookId"],
              notes: n["notes"],
              notes_in_flow: n["notesInFlow"],
              always_output_data: n["alwaysOutputData"],
              on_error: n["onError"],
              continue_on_fail: n["continueOnFail"],
            ).freeze
          end
      @nodes_by_id = @nodes.index_by(&:id)
      @nodes_by_name = @nodes.index_by(&:name)

      @connections =
        DiscourseWorkflows::WorkflowDocument
          .connection_records(@nodes.map(&:to_workflow_node), data.fetch("connections") { {} })
          .map do |c|
            SnapshotConnection.new(
              source_node_id: c["source_node_id"].to_s,
              source_output_index: c["source_output_index"].to_i,
              target_node_id: c["target_node_id"].to_s,
              target_input_index: c["target_input_index"].to_i,
              connection_type: c["connection_type"] || "main",
            ).freeze
          end

      @connections_by_source = @connections.group_by(&:source_node_id)
      @connections_by_source_output_index =
        @connections.group_by do |connection|
          [connection.source_node_id, connection.source_output_index]
        end
      @connections_by_target = @connections.group_by(&:target_node_id)
    end

    def find_node(node_id)
      @nodes_by_id[node_id.to_s]
    end

    def find_node_by_name(node_name)
      @nodes_by_name[node_name.to_s]
    end

    def child_nodes(node_name, connection_type: "main", depth: -1)
      connected_nodes(
        node_name,
        direction: :downstream,
        connection_type: connection_type,
        depth: depth,
      )
    end

    def parent_nodes(node_name, connection_type: "main", depth: -1)
      connected_nodes(
        node_name,
        direction: :upstream,
        connection_type: connection_type,
        depth: depth,
      )
    end

    def connections_from_output_index(node, output_index)
      @connections_by_source_output_index.fetch([node.id, output_index.to_i]) { [] }
    end

    def connections_to(node)
      @connections_by_target.fetch(node.id) { [] }
    end

    def target_node(connection)
      @nodes_by_id[connection.target_node_id]
    end

    def source_node(connection)
      @nodes_by_id[connection.source_node_id]
    end

    def node_has_reachable_downstream_of_type?(node_id, type)
      visited = Set.new
      queue = [node_id.to_s]

      while (current = queue.shift)
        next if visited.include?(current)
        visited << current

        @connections_by_source
          .fetch(current) { [] }
          .each do |connection|
            target_node = target_node(connection)
            next unless target_node
            return true if target_node.type == type

            queue << target_node.id
          end
      end

      false
    end

    def connected_nodes(node_name, direction:, connection_type: "main", depth: -1)
      start_node = find_node_by_name(node_name) || find_node(node_name)
      return [] if start_node.blank?

      collect_connected_nodes(
        start_node.id,
        direction: direction,
        connection_type: connection_type.to_s,
        depth: depth.to_i,
        checked_nodes: Set.new,
      )
    end

    def to_h
      workflow_nodes = nodes.map(&:to_workflow_node)
      {
        "name" => workflow_name.presence,
        "nodes" => workflow_nodes,
        "connections" =>
          DiscourseWorkflows::WorkflowDocument.connections_from_records(
            workflow_nodes,
            connections,
          ),
        "pinData" => pin_data,
      }.compact
    end

    def self.from_workflow(workflow, published: false)
      nodes = published ? workflow.published_nodes : workflow.nodes
      connections = published ? workflow.published_connections : workflow.connections
      workflow_name = published ? workflow.active_version&.name : workflow.name
      new(
        "name" => workflow_name || workflow.name,
        "nodes" => nodes,
        "connections" => connections,
        "pinData" => workflow.pin_data || {},
      )
    end

    def self.from_version(workflow, version)
      new(
        "name" => version.name || workflow.name,
        "nodes" => version.nodes,
        "connections" => version.connections,
      )
    end

    private

    def collect_connected_nodes(node_id, direction:, connection_type:, depth:, checked_nodes:)
      return [] if depth.zero?
      return [] if checked_nodes.include?(node_id)

      next_depth = depth.negative? ? depth : depth - 1
      next_checked_nodes = checked_nodes.dup
      next_checked_nodes << node_id
      connected = []

      connections_for(node_id, direction).each do |connection|
        next unless connection_type_matches?(connection, connection_type)

        node = direction == :downstream ? target_node(connection) : source_node(connection)
        next if node.blank? || next_checked_nodes.include?(node.id)

        connected.unshift(node)
        collect_connected_nodes(
          node.id,
          direction: direction,
          connection_type: connection_type,
          depth: next_depth,
          checked_nodes: next_checked_nodes,
        ).reverse_each do |connected_node|
          index = connected.index { |existing_node| existing_node.id == connected_node.id }
          connected.delete_at(index) if index
          connected.unshift(connected_node)
        end
      end

      connected
    end

    def connections_for(node_id, direction)
      case direction
      when :downstream
        @connections_by_source.fetch(node_id) { [] }
      when :upstream
        @connections_by_target.fetch(node_id) { [] }
      else
        raise ArgumentError, "Unknown connection direction: #{direction}"
      end
    end

    def connection_type_matches?(connection, connection_type)
      case connection_type
      when "ALL"
        true
      when "ALL_NON_MAIN"
        connection.connection_type != "main"
      else
        connection.connection_type == connection_type
      end
    end
  end
end
