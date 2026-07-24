# frozen_string_literal: true

module DiscourseWorkflows
  module WorkflowDocument
    DEFAULT_CONNECTION_TYPE = "main"

    module_function

    def normalize_connections(nodes, connections)
      return {} unless connections.is_a?(Hash)

      node_names = Set.new(nodes.map { |node| node["name"].to_s })

      connections.each_with_object({}) do |(source_name, outputs_by_type), normalized|
        source_name = source_name.to_s
        next if source_name.blank? || !node_names.include?(source_name)
        next unless outputs_by_type.is_a?(Hash)

        outputs_by_type.each do |connection_type, output_connections|
          connection_type = connection_type.presence || DEFAULT_CONNECTION_TYPE
          normalized_outputs = normalize_output_connections(output_connections, node_names)
          next if normalized_outputs.all?(&:blank?)

          normalized[source_name] ||= {}
          normalized[source_name][connection_type] = normalized_outputs
        end
      end
    end

    def connection_records(nodes, connections)
      nodes_by_name = nodes.index_by { |node| node["name"].to_s }

      normalize_connections(nodes, connections).flat_map do |source_name, outputs_by_type|
        source_node = nodes_by_name[source_name]
        next [] unless source_node

        outputs_by_type.flat_map do |connection_type, output_connections|
          Array(output_connections).flat_map.with_index do |target_connections, source_output_index|
            Array(target_connections).filter_map do |target_connection|
              target_node = nodes_by_name[target_connection["node"].to_s]
              next unless target_node

              {
                "source_node_id" => source_node["id"].to_s,
                "source_output_index" => source_output_index,
                "target_node_id" => target_node["id"].to_s,
                "target_input_index" => target_connection["index"].to_i,
                "connection_type" => target_connection["type"].presence || connection_type,
              }
            end
          end
        end
      end
    end

    def connections_from_records(nodes, connection_records)
      nodes_by_id = nodes.index_by { |node| node["id"].to_s }

      Array(connection_records).each_with_object({}) do |connection, result|
        source_node = nodes_by_id[read_connection(connection, "source_node_id").to_s]
        target_node = nodes_by_id[read_connection(connection, "target_node_id").to_s]
        next if source_node.blank? || target_node.blank?

        source_name = source_node["name"].to_s
        target_name = target_node["name"].to_s
        connection_type =
          read_connection(connection, "connection_type").presence || DEFAULT_CONNECTION_TYPE
        source_output_index = read_connection(connection, "source_output_index").to_i
        target_input_index = read_connection(connection, "target_input_index").to_i

        result[source_name] ||= {}
        result[source_name][connection_type] ||= []
        while result[source_name][connection_type].length <= source_output_index
          result[source_name][connection_type] << []
        end
        result[source_name][connection_type][source_output_index] << {
          "node" => target_name,
          "type" => connection_type,
          "index" => target_input_index,
        }
      end
    end

    def workflow_payload(workflow, published: false)
      version = published ? workflow.active_version : nil
      nodes = published ? workflow.published_nodes : workflow.nodes
      connections = published ? workflow.published_connections : workflow.connections
      name = version&.name || workflow.name

      {
        "id" => workflow.id.to_s,
        "name" => name,
        "nodes" => nodes || [],
        "connections" => connections || {},
        "settings" => (published ? version&.settings : workflow.settings) || {},
        "staticData" => workflow.normalized_static_data,
        "pinData" => workflow.pin_data || {},
        "versionId" => (published ? version&.version_id : workflow.version_id),
        "activeVersionId" => workflow.active_version_id,
        "versionCounter" => workflow.version_counter,
      }
    end

    def node_type_version(node)
      if node.respond_to?(:type_version)
        node.type_version
      else
        node["typeVersion"]
      end
    end

    def node_webhook_id(node)
      if node.respond_to?(:webhook_id)
        node.webhook_id
      else
        node[node_webhook_id_key]
      end
    end

    def node_type_version_key
      "typeVersion"
    end

    def node_webhook_id_key
      NodeDataShape::FORM_TRIGGER_WEBHOOK_ID_KEY
    end

    def normalize_output_connections(output_connections, node_names)
      Array(output_connections).map do |target_connections|
        next [] if target_connections.nil?

        normalized_targets =
          Array(target_connections).filter_map do |target_connection|
            next unless target_connection.is_a?(Hash)

            target_connection = target_connection.deep_stringify_keys
            target_name = target_connection["node"].to_s
            next if target_name.blank? || !node_names.include?(target_name)

            {
              "node" => target_name,
              "type" => target_connection["type"].presence || DEFAULT_CONNECTION_TYPE,
              "index" => target_connection["index"].to_i,
            }
          end

        normalized_targets.presence || []
      end
    end
    private_class_method :normalize_output_connections

    def read_connection(connection, key)
      return connection.public_send(key) if connection.respond_to?(key)

      connection[key] || connection[key.to_sym]
    end
    private_class_method :read_connection
  end
end
