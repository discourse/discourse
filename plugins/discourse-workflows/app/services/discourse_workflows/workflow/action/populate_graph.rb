# frozen_string_literal: true

module DiscourseWorkflows
  class Workflow::Action::PopulateGraph < Service::ActionBase
    option :workflow
    option :nodes_data
    option :connections_data

    def call
      return false unless validate_nodes
      node_map = build_node_map
      persist_graph!(node_map)
    end

    private

    def build_node_map
      existing_nodes = workflow.parsed_nodes.index_by { |n| n["id"] }
      node_map = {}

      normalized_nodes_data.each_with_index do |node_data, index|
        client_id = node_data[:client_id].to_s
        existing = existing_nodes[client_id]
        node_map[client_id] = build_node_hash(node_data, client_id:, existing:, index:)
      end

      node_map
    end

    def build_node_hash(node_data, client_id:, existing:, index:)
      configuration = resolved_configuration(node_data, existing:)
      configuration = assign_form_uuid(configuration, type: node_data[:type])

      {
        "id" => existing ? existing["id"] : (client_id.presence || SecureRandom.uuid),
        "type" => node_data[:type],
        "type_version" => resolve_type_version(node_data, existing),
        "name" => node_data[:name],
        "position" => node_data[:position],
        "position_index" => index,
        "configuration" => configuration,
      }
    end

    def resolve_type_version(node_data, existing)
      existing&.dig("type_version") || node_data[:type_version] ||
        DiscourseWorkflows::Registry.latest_version(node_data[:type]) ||
        DiscourseWorkflows::Registry::DEFAULT_VERSION
    end

    def persist_graph!(node_map)
      new_nodes = node_map.values
      new_connections = build_connections(node_map)
      attributes = { nodes: new_nodes, connections: new_connections }

      existing_node_ids = workflow.parsed_nodes.map { |n| n["id"] }.to_set
      received_ids = new_nodes.map { |n| n["id"] }.to_set
      removed_ids = existing_node_ids - received_ids

      if removed_ids.any? && workflow.static_data.present?
        attributes[:static_data] = workflow.static_data.except(*removed_ids.to_a)
      end

      workflow.update!(**attributes)
    end

    def validate_nodes
      existing_nodes_index = workflow.parsed_nodes.index_by { |n| n["id"] }

      normalized_nodes_data.each do |node_data|
        existing = existing_nodes_index[node_data[:client_id].to_s]
        type_version = resolve_type_version(node_data, existing)
        validate_node_type(node_data, type_version)
        validate_node_version(node_data, type_version)
      end

      workflow.errors.empty?
    end

    def validate_node_type(node_data, type_version)
      node_type_class =
        DiscourseWorkflows::Registry.find_node_type(node_data[:type], version: type_version)
      configuration = resolved_configuration(node_data, existing: nil)

      if node_type_class.respond_to?(:validate_configuration)
        node_type_class.validate_configuration(configuration, workflow.errors)
      end
    end

    def validate_node_version(node_data, type_version)
      if DiscourseWorkflows::Registry.available_versions(node_data[:type]).exclude?(type_version)
        workflow.errors.add(:base, "Unsupported version #{type_version} for #{node_data[:type]}")
      end
    end

    def build_connections(node_map)
      connections_data.filter_map do |connection_data|
        connection_data = connection_data.symbolize_keys
        source = node_map[connection_data[:source_client_id]]
        target = node_map[connection_data[:target_client_id]]
        next if source.nil? || target.nil?

        {
          "source_node_id" => source["id"],
          "target_node_id" => target["id"],
          "source_output" => connection_data[:source_output] || "main",
        }
      end
    end

    def normalized_nodes_data
      @normalized_nodes_data ||= nodes_data.map(&:symbolize_keys)
    end

    def resolved_configuration(node_data, existing:)
      configuration = (node_data[:configuration] || {}).deep_stringify_keys

      if existing&.dig("configuration", "uuid").present?
        configuration.merge("uuid" => existing.dig("configuration", "uuid"))
      else
        configuration
      end
    end

    def assign_form_uuid(configuration, type:)
      return configuration unless type == "trigger:form"
      return configuration if configuration["uuid"].present?

      configuration.merge("uuid" => SecureRandom.uuid)
    end
  end
end
