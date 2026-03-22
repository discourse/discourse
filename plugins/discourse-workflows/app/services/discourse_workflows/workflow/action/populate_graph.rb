# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::PopulateGraph < Service::ActionBase
    option :workflow
    option :nodes_data
    option :connections_data

    def call
      node_map = upsert_nodes
      sync_connections(node_map)
    end

    private

    def upsert_nodes
      existing_nodes = workflow.nodes.index_by { |n| n.id.to_s }
      received_client_ids = Set.new

      node_map =
        nodes_data.each_with_index.to_h do |node_data, index|
          node_data = node_data.symbolize_keys
          client_id = node_data[:client_id].to_s
          existing = existing_nodes[client_id]

          configuration = node_data[:configuration] || {}
          if existing && existing.configuration["uuid"].present?
            configuration = configuration.merge("uuid" => existing.configuration["uuid"])
          end

          attrs = {
            type: node_data[:type],
            name: node_data[:name],
            position: node_data[:position],
            position_index: index,
            configuration: configuration,
          }

          node =
            if existing
              existing.update!(**attrs)
              existing
            else
              workflow.nodes.create!(**attrs)
            end

          received_client_ids.add(client_id)
          [client_id, node]
        end

      # Generate UUIDs for form trigger nodes that don't have one
      node_map.each_value do |node|
        if node.type == "trigger:form" && node.configuration["uuid"].blank?
          node.update!(configuration: node.configuration.merge("uuid" => SecureRandom.uuid))
        end
      end

      stale_ids = (existing_nodes.keys.to_set - received_client_ids).map(&:to_i)
      if stale_ids.any?
        workflow
          .connections
          .where(source_node_id: stale_ids)
          .or(workflow.connections.where(target_node_id: stale_ids))
          .delete_all
        workflow.nodes.where(id: stale_ids).delete_all
      end

      node_map
    end

    def sync_connections(node_map)
      workflow.connections.delete_all

      connections_data.each do |connection_data|
        connection_data = connection_data.symbolize_keys
        source = node_map[connection_data[:source_client_id]]
        target = node_map[connection_data[:target_client_id]]
        next if source.nil? || target.nil?

        workflow.connections.create!(
          source_node: source,
          target_node: target,
          source_output: connection_data[:source_output] || "main",
        )
      end
    end
  end
end
