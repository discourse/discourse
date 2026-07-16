# frozen_string_literal: true

module DiscourseWorkflows
  module Schema
    class GraphResolver
      def self.call(nodes, connections)
        new(nodes, connections).call
      end

      def initialize(nodes, connections)
        @nodes = Array(nodes)
        @connection_records = WorkflowDocument.connection_records(@nodes, connections)
        @nodes_by_id = @nodes.index_by { |node| NodeData.read(node, "id").to_s }
        @node_classes =
          @nodes_by_id.transform_values do |node|
            Registry.find_node_type(
              NodeData.read(node, "type"),
              version: NodeData.type_version(node),
            )
          end
        @incoming_connections =
          @connection_records
            .reject { |record| record["source_node_id"].to_s == record["target_node_id"].to_s }
            .group_by { |record| record["target_node_id"].to_s }
        @incoming_connections.each_value do |records|
          records.sort_by! do |record|
            [
              record["target_input_index"].to_i,
              record["source_output_index"].to_i,
              record["source_node_id"].to_s,
            ]
          end
        end
        @input_schemas = {}
        @output_schemas = {}
      end

      def call
        sweep_until_stable
        sweep_until_stable if promote_unresolved_outputs
        resolve_remaining_inputs

        {
          input_schemas: @input_schemas,
          output_schemas: @output_schemas,
          connection_records: @connection_records,
        }
      end

      private

      def sweep_until_stable
        changed = true
        sweeps = 0

        while changed
          if (sweeps += 1) > @nodes.length + 2
            raise ArgumentError, "Output schema graph did not converge"
          end

          changed = false
          @nodes_by_id.each_key do |node_id|
            input_schemas, resolved = input_schemas_for(node_id)
            next unless resolved

            output_schemas = output_schemas_for(node_id, input_schemas)
            changed ||= @output_schemas[node_id] != output_schemas
            @input_schemas[node_id] = input_schemas
            @output_schemas[node_id] = output_schemas
          end
        end
      end

      def promote_unresolved_outputs
        unresolved = @nodes_by_id.keys.reject { |node_id| @output_schemas.key?(node_id) }
        unresolved.each do |node_id|
          @output_schemas[node_id] = Array.new(output_count(node_id)) { {} }
        end
        unresolved.any?
      end

      def resolve_remaining_inputs
        @nodes_by_id.each_key do |node_id|
          @input_schemas[node_id] ||= input_schemas_for(node_id).first
        end
      end

      def output_schemas_for(node_id, input_schemas)
        node_class = @node_classes[node_id]
        return [{}] unless node_class

        node_class.output_schemas(
          NodeData.parameters(@nodes_by_id.fetch(node_id)),
          input_schemas: input_schemas,
        )
      end

      def input_schemas_for(node_id)
        connections = Array(@incoming_connections[node_id])
        count = input_count(node_id, connections)
        return Array.new(count), true if connections.empty?

        schemas_by_index =
          Array.new(count) do |input_index|
            schemas =
              connections.filter_map do |connection|
                next if connection["target_input_index"].to_i != input_index

                source_outputs = @output_schemas[connection["source_node_id"].to_s]
                next if source_outputs.nil?

                source_outputs[connection["source_output_index"].to_i] || {}
              end

            Schema.union(*schemas) if schemas.any?
          end

        [
          schemas_by_index,
          schemas_by_index.any? { |schema| !schema.nil? } || replace_only?(node_id),
        ]
      end

      def replace_only?(node_id)
        node_class = @node_classes[node_id]
        return false unless node_class.respond_to?(:active_output_contracts)

        node_class
          .active_output_contracts(NodeData.parameters(@nodes_by_id.fetch(node_id)))
          .all? { |contract| contract.fetch(:mode).to_sym == :replace }
      end

      def output_count(node_id)
        node_class = @node_classes[node_id]
        return 1 unless node_class.respond_to?(:ports)

        node_class.ports(NodeData.parameters(@nodes_by_id.fetch(node_id))).length
      end

      def input_count(node_id, connections)
        node_class = @node_classes[node_id]
        declared_count =
          if node_class.respond_to?(:input_ports)
            node_class.input_ports(NodeData.parameters(@nodes_by_id.fetch(node_id))).length
          else
            1
          end

        [
          declared_count,
          connections.map { |connection| connection["target_input_index"].to_i + 1 }.max.to_i,
        ].max
      end
    end
  end
end
